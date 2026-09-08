#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Verifies release artifact provenance using the same semantics as the release workflow.

.DESCRIPTION
    Scans a directory of downloaded release artifacts and runs gh attestation verify
    with the correct signer workflow and predicate arguments for VSIX, plugin zip,
    and VEX files.

.PARAMETER ArtifactDirectory
    Directory containing downloaded release artifacts.

.PARAMETER Repository
    GitHub repository in owner/name format.

.PARAMETER ExpectedSourceSha
    Full source commit SHA validated by the release producer.

.PARAMETER ExpectedSignerSha
    Full immutable commit SHA containing the trusted signer workflow definition.

.PARAMETER ReleaseTag
    Canonical release tag validated by the release producer.

.EXAMPLE
    ./Invoke-ProvenanceVerification.ps1 -ArtifactDirectory ./artifacts -Repository microsoft/hve-core -ExpectedSourceSha 0123456789012345678901234567890123456789 -ExpectedSignerSha abcdefabcdefabcdefabcdefabcdefabcdefabcd -ReleaseTag v3.4.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ArtifactDirectory = $env:ARTIFACT_DIRECTORY,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository = $env:REPOSITORY,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedSourceSha = $env:EXPECTED_SOURCE_SHA,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedSignerSha = $env:EXPECTED_SIGNER_SHA,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:v|prerelease-v)[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$ReleaseTag = $env:RELEASE_TAG
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ExternalCommand {
    <#
    .SYNOPSIS
        Runs an external command and throws on non-zero exit code.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $Output = @(& $Command @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "External verification command failed with exit code ${LASTEXITCODE}"
    }

    return $Output
}

function Assert-JsonObject {
    <#
    .SYNOPSIS
        Requires a policy value to be a JSON object.
    .PARAMETER Value
        Candidate value to validate.
    .PARAMETER Invariant
        Policy invariant name used in validation errors.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Invariant
    )

    if ($null -eq $Value -or $Value -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Provenance invariant failed: $Invariant must be an object"
    }
}

function Assert-JsonArray {
    <#
    .SYNOPSIS
        Requires a policy value to be a JSON array.
    .PARAMETER Value
        Candidate value to validate.
    .PARAMETER Invariant
        Policy invariant name used in validation errors.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Invariant
    )

    if ($null -eq $Value -or $Value -isnot [System.Array]) {
        throw "Provenance invariant failed: $Invariant must be an array"
    }
}

function Assert-PropertySet {
    <#
    .SYNOPSIS
        Requires a JSON object to contain only an allowed property set.
    .PARAMETER Value
        JSON object whose properties are validated.
    .PARAMETER Required
        Property names that must be present.
    .PARAMETER Allowed
        Complete property names allowed on the object.
    .PARAMETER Invariant
        Policy invariant name used in validation errors.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Value,

        [Parameter(Mandatory = $true)]
        [string[]]$Required,

        [Parameter(Mandatory = $true)]
        [string[]]$Allowed,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Invariant
    )

    $Actual = @($Value.PSObject.Properties.Name)
    $Missing = @($Required | Where-Object { $_ -notin $Actual })
    $Unknown = @($Actual | Where-Object { $_ -notin $Allowed })
    if ($Missing.Count -gt 0 -or $Unknown.Count -gt 0) {
        throw "Provenance invariant failed: $Invariant has a missing or unknown field"
    }
}

function Assert-ExactString {
    <#
    .SYNOPSIS
        Requires an exact ordinal string value.
    .PARAMETER Actual
        Candidate value to validate.
    .PARAMETER Expected
        Exact string required by the policy.
    .PARAMETER Invariant
        Policy invariant name used in validation errors.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Actual,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Expected,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Invariant
    )

    if ($Actual -isnot [string] -or -not [string]::Equals($Actual, $Expected, [System.StringComparison]::Ordinal)) {
        throw "Provenance invariant failed: $Invariant does not match the expected value"
    }
}

function Assert-VsixProvenancePolicy {
    <#
    .SYNOPSIS
        Enforces release policy on authenticated GitHub CLI verification output.
    .PARAMETER VerificationJson
        Authenticated JSON emitted by GitHub CLI attestation verification.
    .PARAMETER Artifact
        Local VSIX file whose subject name and digest must match.
    .PARAMETER Repository
        Expected GitHub repository in owner/name format.
    .PARAMETER ExpectedSourceSha
        Full source commit SHA validated by the release producer.
    .PARAMETER ReleaseTag
        Canonical release tag validated by the release producer.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VerificationJson,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$Artifact,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Repository,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$ExpectedSourceSha,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseTag
    )

    try {
        $Results = ConvertFrom-Json -InputObject $VerificationJson -Depth 30 -NoEnumerate
    }
    catch {
        throw 'Provenance invariant failed: authenticated verification output is malformed JSON'
    }

    Assert-JsonArray -Value $Results -Invariant 'authenticated verification output'
    if ($Results.Count -ne 1) {
        throw 'Provenance invariant failed: authenticated verification output must contain exactly one result'
    }

    $Result = $Results[0]
    Assert-JsonObject -Value $Result -Invariant 'verification result'
    Assert-PropertySet -Value $Result -Required @('attestation', 'verificationResult') -Allowed @('attestation', 'verificationResult') -Invariant 'verification result'
    Assert-JsonObject -Value $Result.attestation -Invariant 'verified attestation'
    Assert-JsonObject -Value $Result.verificationResult -Invariant 'verificationResult'
    Assert-PropertySet -Value $Result.verificationResult -Required @('signature', 'verifiedTimestamps', 'statement') -Allowed @('signature', 'verifiedTimestamps', 'statement') -Invariant 'verificationResult'

    $Statement = $Result.verificationResult.statement
    Assert-JsonObject -Value $Statement -Invariant 'statement'
    Assert-PropertySet -Value $Statement -Required @('_type', 'subject', 'predicateType', 'predicate') -Allowed @('_type', 'subject', 'predicateType', 'predicate') -Invariant 'statement'
    Assert-ExactString -Actual $Statement._type -Expected 'https://in-toto.io/Statement/v1' -Invariant 'statement type'
    Assert-ExactString -Actual $Statement.predicateType -Expected 'https://slsa.dev/provenance/v1' -Invariant 'predicate type'

    Assert-JsonArray -Value $Statement.subject -Invariant 'statement subject'
    if ($Statement.subject.Count -ne 1) {
        throw 'Provenance invariant failed: statement must contain exactly one subject'
    }

    $Subject = $Statement.subject[0]
    Assert-JsonObject -Value $Subject -Invariant 'statement subject'
    Assert-PropertySet -Value $Subject -Required @('name', 'digest') -Allowed @('name', 'digest') -Invariant 'statement subject'
    Assert-ExactString -Actual $Subject.name -Expected $Artifact.Name -Invariant 'subject name'
    Assert-JsonObject -Value $Subject.digest -Invariant 'subject digest'
    Assert-PropertySet -Value $Subject.digest -Required @('sha256') -Allowed @('sha256') -Invariant 'subject digest'
    $LocalDigest = (Get-FileHash -LiteralPath $Artifact.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-ExactString -Actual $Subject.digest.sha256 -Expected $LocalDigest -Invariant 'subject digest'

    $Predicate = $Statement.predicate
    Assert-JsonObject -Value $Predicate -Invariant 'predicate'
    Assert-PropertySet -Value $Predicate -Required @('buildDefinition', 'runDetails') -Allowed @('buildDefinition', 'runDetails') -Invariant 'predicate'

    $BuildDefinition = $Predicate.buildDefinition
    Assert-JsonObject -Value $BuildDefinition -Invariant 'build definition'
    Assert-PropertySet -Value $BuildDefinition -Required @('buildType', 'externalParameters', 'internalParameters', 'resolvedDependencies') -Allowed @('buildType', 'externalParameters', 'internalParameters', 'resolvedDependencies') -Invariant 'build definition'
    Assert-ExactString -Actual $BuildDefinition.buildType -Expected 'https://actions.github.io/buildtypes/workflow/v1' -Invariant 'build type'

    $ExternalParameters = $BuildDefinition.externalParameters
    Assert-JsonObject -Value $ExternalParameters -Invariant 'external parameters'
    Assert-PropertySet -Value $ExternalParameters -Required @('workflow') -Allowed @('workflow') -Invariant 'external parameters'
    Assert-JsonObject -Value $ExternalParameters.workflow -Invariant 'external workflow'
    Assert-PropertySet -Value $ExternalParameters.workflow -Required @('ref', 'repository', 'path') -Allowed @('ref', 'repository', 'path') -Invariant 'external workflow'
    Assert-ExactString -Actual $ExternalParameters.workflow.ref -Expected "refs/tags/$ReleaseTag" -Invariant 'external workflow ref'
    Assert-ExactString -Actual $ExternalParameters.workflow.repository -Expected "https://github.com/$Repository" -Invariant 'external workflow repository'
    Assert-ExactString -Actual $ExternalParameters.workflow.path -Expected '.github/workflows/release-vsix-publish.yml' -Invariant 'external workflow path'

    $InternalParameters = $BuildDefinition.internalParameters
    Assert-JsonObject -Value $InternalParameters -Invariant 'internal parameters'
    Assert-PropertySet -Value $InternalParameters -Required @('github') -Allowed @('github') -Invariant 'internal parameters'
    Assert-JsonObject -Value $InternalParameters.github -Invariant 'internal GitHub parameters'
    Assert-PropertySet -Value $InternalParameters.github -Required @('event_name', 'repository_id', 'repository_owner_id', 'runner_environment') -Allowed @('event_name', 'repository_id', 'repository_owner_id', 'runner_environment') -Invariant 'internal GitHub parameters'
    Assert-ExactString -Actual $InternalParameters.github.event_name -Expected 'push' -Invariant 'event name'
    Assert-ExactString -Actual $InternalParameters.github.runner_environment -Expected 'github-hosted' -Invariant 'runner environment'
    foreach ($IdentifierName in @('repository_id', 'repository_owner_id')) {
        $Identifier = $InternalParameters.github.$IdentifierName
        if ($Identifier -isnot [string] -or $Identifier -notmatch '^[0-9]+$') {
            throw "Provenance invariant failed: $IdentifierName must be a nonempty decimal identifier"
        }
    }

    Assert-JsonArray -Value $BuildDefinition.resolvedDependencies -Invariant 'resolved dependencies'
    if ($BuildDefinition.resolvedDependencies.Count -ne 1) {
        throw 'Provenance invariant failed: resolved dependencies must contain exactly one entry'
    }
    $Dependency = $BuildDefinition.resolvedDependencies[0]
    Assert-JsonObject -Value $Dependency -Invariant 'resolved dependency'
    Assert-PropertySet -Value $Dependency -Required @('uri', 'digest') -Allowed @('uri', 'digest') -Invariant 'resolved dependency'
    Assert-ExactString -Actual $Dependency.uri -Expected "git+https://github.com/$Repository@refs/tags/$ReleaseTag" -Invariant 'resolved dependency URI'
    Assert-JsonObject -Value $Dependency.digest -Invariant 'resolved dependency digest'
    Assert-PropertySet -Value $Dependency.digest -Required @('gitCommit') -Allowed @('gitCommit') -Invariant 'resolved dependency digest'
    Assert-ExactString -Actual $Dependency.digest.gitCommit -Expected $ExpectedSourceSha -Invariant 'resolved dependency digest'

    $RunDetails = $Predicate.runDetails
    Assert-JsonObject -Value $RunDetails -Invariant 'run details'
    Assert-PropertySet -Value $RunDetails -Required @('builder') -Allowed @('builder', 'metadata', 'byproducts') -Invariant 'run details'
    Assert-JsonObject -Value $RunDetails.builder -Invariant 'builder'
    Assert-PropertySet -Value $RunDetails.builder -Required @('id') -Allowed @('id') -Invariant 'builder'
    Assert-ExactString -Actual $RunDetails.builder.id -Expected "https://github.com/$Repository/.github/workflows/release-vsix-publish.yml@refs/tags/$ReleaseTag" -Invariant 'builder identity'
    if ($RunDetails.PSObject.Properties.Name -contains 'metadata') {
        Assert-JsonObject -Value $RunDetails.metadata -Invariant 'run metadata'
    }
    if ($RunDetails.PSObject.Properties.Name -contains 'byproducts') {
        Assert-JsonArray -Value $RunDetails.byproducts -Invariant 'run byproducts'
    }
}

function Assert-VsixProvenanceSidecars {
    <#
    .SYNOPSIS
        Requires released provenance sidecars to match the authenticated bundle.
    .PARAMETER VerificationJson
        Authenticated JSON emitted by GitHub CLI bundle verification.
    .PARAMETER SigstorePath
        Released Sigstore bundle path supplied to GitHub CLI.
    .PARAMETER IntotoPath
        Released in-toto JSON Lines sidecar path.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VerificationJson,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SigstorePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$IntotoPath
    )

    try {
        $Results = ConvertFrom-Json -InputObject $VerificationJson -Depth 100 -NoEnumerate
        $ReleasedBundle = Get-Content -LiteralPath $SigstorePath -Raw -Encoding utf8 |
            ConvertFrom-Json -Depth 100
        $IntotoLines = @(Get-Content -LiteralPath $IntotoPath -Encoding utf8 |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    catch {
        throw 'Provenance invariant failed: released provenance sidecar is malformed JSON'
    }

    if ($Results -isnot [System.Array] -or $Results.Count -ne 1) {
        throw 'Provenance invariant failed: bundle verification must contain exactly one result'
    }
    if ($IntotoLines.Count -ne 1) {
        throw 'Provenance invariant failed: released in-toto sidecar must contain exactly one envelope'
    }
    try {
        $ReleasedEnvelope = ConvertFrom-Json -InputObject $IntotoLines[0] -Depth 100
    }
    catch {
        throw 'Provenance invariant failed: released in-toto sidecar is malformed JSON'
    }
    if (-not $ReleasedBundle.PSObject.Properties['dsseEnvelope']) {
        throw 'Provenance invariant failed: released Sigstore bundle has no DSSE envelope'
    }

    $AuthenticatedBundleJson = ConvertTo-Json -InputObject $Results[0].attestation -Depth 100 -Compress
    $ReleasedBundleJson = ConvertTo-Json -InputObject $ReleasedBundle -Depth 100 -Compress
    if (-not [string]::Equals($AuthenticatedBundleJson, $ReleasedBundleJson, [System.StringComparison]::Ordinal)) {
        throw 'Provenance invariant failed: authenticated bundle differs from released Sigstore sidecar'
    }
    $BundleEnvelopeJson = ConvertTo-Json -InputObject $ReleasedBundle.dsseEnvelope -Depth 100 -Compress
    $ReleasedEnvelopeJson = ConvertTo-Json -InputObject $ReleasedEnvelope -Depth 100 -Compress
    if (-not [string]::Equals($BundleEnvelopeJson, $ReleasedEnvelopeJson, [System.StringComparison]::Ordinal)) {
        throw 'Provenance invariant failed: released in-toto sidecar differs from the authenticated bundle envelope'
    }
}

function Invoke-ProvenanceVerification {
    <#
    .SYNOPSIS
        Verifies provenance for downloaded release artifacts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArtifactDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
        [string]$Repository,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$ExpectedSourceSha,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$ExpectedSignerSha,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^(?:v|prerelease-v)[0-9]+\.[0-9]+\.[0-9]+$')]
        [string]$ReleaseTag
    )

    if (-not (Test-Path -Path $ArtifactDirectory -PathType Container)) {
        throw "Artifact directory not found: $ArtifactDirectory"
    }

    $artifacts = @(Get-ChildItem -Path $ArtifactDirectory -File | Sort-Object Name)
    if ($artifacts.Count -eq 0) {
        throw "No release artifacts found in $ArtifactDirectory"
    }

    $VsixArtifacts = @($artifacts | Where-Object { $_.Name -like '*.vsix' })
    if ($VsixArtifacts.Count -ne 1) {
        throw 'Provenance invariant failed: release artifacts must contain exactly one VSIX'
    }

    $VsixArtifact = $VsixArtifacts[0]
    $SigstorePath = "$($VsixArtifact.FullName).sigstore.json"
    $IntotoPath = "$($VsixArtifact.FullName).intoto.jsonl"
    foreach ($SidecarPath in @($SigstorePath, $IntotoPath)) {
        if (-not (Test-Path -LiteralPath $SidecarPath -PathType Leaf)) {
            throw "Provenance invariant failed: required provenance sidecar not found: $([System.IO.Path]::GetFileName($SidecarPath))"
        }
    }

    foreach ($artifact in $artifacts) {
        $fullPath = [System.IO.Path]::GetFullPath($artifact.FullName)
        if ($artifact.Name -like '*.vsix') {
            $Arguments = @(
                'attestation', 'verify', $fullPath,
                '--repo', $Repository,
                '--bundle', $SigstorePath,
                '--signer-workflow', "$Repository/.github/workflows/extension-provenance-signer.yml",
                '--signer-digest', $ExpectedSignerSha,
                '--source-digest', $ExpectedSourceSha,
                '--source-ref', "refs/tags/$ReleaseTag",
                '--predicate-type', 'https://slsa.dev/provenance/v1',
                '--deny-self-hosted-runners',
                '--format', 'json'
            )
            $VerificationOutput = @(Invoke-ExternalCommand -Command 'gh' -Arguments $Arguments)
            $VerificationJson = $VerificationOutput -join [Environment]::NewLine
            Assert-VsixProvenancePolicy -VerificationJson $VerificationJson -Artifact $artifact -Repository $Repository -ExpectedSourceSha $ExpectedSourceSha -ReleaseTag $ReleaseTag
            Assert-VsixProvenanceSidecars -VerificationJson $VerificationJson -SigstorePath $SigstorePath -IntotoPath $IntotoPath
        }
        elseif ($artifact.Name -like '*.zip') {
            $null = Invoke-ExternalCommand -Command 'gh' -Arguments @('attestation', 'verify', $fullPath, '--repo', $Repository)
        }
        elseif ($artifact.Name -eq 'hve-core.openvex.json') {
            $null = Invoke-ExternalCommand -Command 'gh' -Arguments @('attestation', 'verify', $fullPath, '--repo', $Repository, '--signer-workflow', "$Repository/.github/workflows/vex-attest.yml", '--predicate-type', 'https://openvex.dev/ns/v0.2.0')
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ProvenanceVerification -ArtifactDirectory $ArtifactDirectory -Repository $Repository -ExpectedSourceSha $ExpectedSourceSha -ExpectedSignerSha $ExpectedSignerSha -ReleaseTag $ReleaseTag
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-ProvenanceVerification failed: $($_.Exception.Message)"
        exit 1
    }
}
