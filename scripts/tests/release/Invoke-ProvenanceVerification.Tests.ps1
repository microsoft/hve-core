#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../release/Invoke-ProvenanceVerification.ps1')

    $script:Repository = 'microsoft/hve-core'
    $script:SourceSha = '0123456789abcdef0123456789abcdef01234567'
    $script:SignerSha = 'abcdef0123456789abcdef0123456789abcdef01'
    $script:ReleaseTag = 'v3.4.0'

    function New-VerifiedResultFixture {
        <#
        .SYNOPSIS
            Creates a valid authenticated VSIX provenance result fixture.
        .PARAMETER VsixPath
            VSIX fixture whose name and SHA-256 digest populate the statement.
        .OUTPUTS
            [pscustomobject] Authenticated verification result fixture.
        #>
        [CmdletBinding()]
        [OutputType([pscustomobject])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$VsixPath
        )

        $Digest = (Get-FileHash -LiteralPath $VsixPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $Fixture = [ordered]@{
            attestation       = [ordered]@{
                mediaType = 'application/vnd.dev.sigstore.bundle.v0.3+json'
                dsseEnvelope = [ordered]@{
                    payloadType = 'application/vnd.in-toto+json'
                    payload = 'c2FuaXRpemVk'
                    signatures = @([ordered]@{ keyid = ''; sig = 'c2lnbmF0dXJl' })
                }
            }
            verificationResult = [ordered]@{
                signature          = [ordered]@{
                    certificate = [ordered]@{ subjectAlternativeName = 'sanitized' }
                }
                verifiedTimestamps = @([ordered]@{ type = 'transparency-log'; timestamp = '2026-08-28T00:00:00Z' })
                statement          = [ordered]@{
                    _type         = 'https://in-toto.io/Statement/v1'
                    subject       = @(
                        [ordered]@{
                            name   = [System.IO.Path]::GetFileName($VsixPath)
                            digest = [ordered]@{ sha256 = $Digest }
                        }
                    )
                    predicateType = 'https://slsa.dev/provenance/v1'
                    predicate     = [ordered]@{
                        buildDefinition = [ordered]@{
                            buildType            = 'https://actions.github.io/buildtypes/workflow/v1'
                            externalParameters   = [ordered]@{
                                workflow = [ordered]@{
                                    ref        = "refs/tags/$script:ReleaseTag"
                                    repository = "https://github.com/$script:Repository"
                                    path       = '.github/workflows/release-vsix-publish.yml'
                                }
                            }
                            internalParameters   = [ordered]@{
                                github = [ordered]@{
                                    event_name          = 'push'
                                    repository_id       = '123456789'
                                    repository_owner_id = '987654321'
                                    runner_environment  = 'github-hosted'
                                }
                            }
                            resolvedDependencies = @(
                                [ordered]@{
                                    uri    = "git+https://github.com/$script:Repository@refs/tags/$script:ReleaseTag"
                                    digest = [ordered]@{ gitCommit = $script:SourceSha }
                                }
                            )
                        }
                        runDetails      = [ordered]@{
                            builder  = [ordered]@{
                                id = "https://github.com/$script:Repository/.github/workflows/release-vsix-publish.yml@refs/tags/$script:ReleaseTag"
                            }
                            metadata = [ordered]@{ invocationId = 'https://github.com/microsoft/hve-core/actions/runs/1/attempts/1' }
                        }
                    }
                }
            }
        }

        return ($Fixture | ConvertTo-Json -Depth 30 | ConvertFrom-Json -Depth 30)
    }
}

Describe 'Invoke-ProvenanceVerification' -Tag 'Unit' {
    BeforeEach {
        $script:tempDir = Join-Path $TestDrive 'artifacts'
        if (Test-Path -LiteralPath $script:tempDir) {
            Remove-Item -LiteralPath $script:tempDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
        $script:vsixPath = Join-Path $script:tempDir 'sample.vsix'
        Set-Content -LiteralPath $script:vsixPath -Value 'sanitized VSIX bytes'
        $script:Fixture = New-VerifiedResultFixture -VsixPath $script:vsixPath
        $script:VerificationJson = ConvertTo-Json -InputObject @($script:Fixture) -Depth 30 -Compress
        $script:SigstorePath = "$script:vsixPath.sigstore.json"
        $script:IntotoPath = "$script:vsixPath.intoto.jsonl"
        $script:Fixture.attestation | ConvertTo-Json -Depth 30 -Compress |
            Set-Content -LiteralPath $script:SigstorePath -Encoding utf8NoBOM
        $script:Fixture.attestation.dsseEnvelope | ConvertTo-Json -Depth 30 -Compress |
            Set-Content -LiteralPath $script:IntotoPath -Encoding utf8NoBOM

        Mock Invoke-ExternalCommand {
            if ($Arguments -contains '--format') {
                return $script:VerificationJson
            }
            return @()
        }
    }

    It 'Accepts one cryptographically verified VSIX with the expected policy' {
        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Not -Throw
    }

    It 'Invokes cryptographic verification before policy parsing with the exact VSIX arguments' {
        Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag

        $ExpectedArguments = @(
            'attestation', 'verify', [System.IO.Path]::GetFullPath($script:vsixPath),
            '--repo', $script:Repository,
            '--bundle', $script:SigstorePath,
            '--signer-workflow', "$script:Repository/.github/workflows/extension-provenance-signer.yml",
            '--signer-digest', $script:SignerSha,
            '--source-digest', $script:SourceSha,
            '--source-ref', "refs/tags/$script:ReleaseTag",
            '--predicate-type', 'https://slsa.dev/provenance/v1',
            '--deny-self-hosted-runners',
            '--format', 'json'
        )
        $ExpectedArgumentString = $ExpectedArguments -join [char]0

        Should -Invoke Invoke-ExternalCommand -Times 1 -Exactly -ParameterFilter {
            $Command -eq 'gh' -and ($Arguments -join [char]0) -ceq $ExpectedArgumentString
        }
    }

    It 'Throws when no artifacts are present' {
        Remove-Item -LiteralPath $script:vsixPath
        Remove-Item -LiteralPath $script:SigstorePath
        Remove-Item -LiteralPath $script:IntotoPath

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*No release artifacts found*'
        Should -Invoke Invoke-ExternalCommand -Times 0 -Exactly
    }

    It 'Rejects release artifacts without a VSIX' {
        Remove-Item -LiteralPath $script:vsixPath
        Set-Content -LiteralPath (Join-Path $script:tempDir 'plugin.zip') -Value 'zip'

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*exactly one VSIX*'
        Should -Invoke Invoke-ExternalCommand -Times 0 -Exactly
    }

    It 'Rejects more than one VSIX before cryptographic verification' {
        Set-Content -LiteralPath (Join-Path $script:tempDir 'second.vsix') -Value 'second'

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*exactly one VSIX*'
        Should -Invoke Invoke-ExternalCommand -Times 0 -Exactly
    }

    It 'Rejects malformed authenticated JSON output' {
        $script:VerificationJson = '{not-json'

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*malformed JSON*'
        Should -Invoke Invoke-ExternalCommand -Times 1 -Exactly
    }

    It 'Rejects a released Sigstore sidecar that differs from the authenticated bundle' {
        $Tampered = $script:Fixture.attestation | ConvertTo-Json -Depth 30 | ConvertFrom-Json -Depth 30
        $Tampered.mediaType = 'application/example'
        $Tampered | ConvertTo-Json -Depth 30 -Compress |
            Set-Content -LiteralPath $script:SigstorePath -Encoding utf8NoBOM

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*authenticated bundle differs from released Sigstore sidecar*'
    }

    It 'Rejects a released in-toto sidecar that differs from its authenticated bundle' {
        '{"payloadType":"application/example","payload":"","signatures":[]}' |
            Set-Content -LiteralPath $script:IntotoPath -Encoding utf8NoBOM

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*released in-toto sidecar differs from the authenticated bundle envelope*'
    }

    It 'Rejects authenticated output that is not an array' {
        $script:VerificationJson = $script:Fixture | ConvertTo-Json -Depth 30 -Compress

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*authenticated verification output must be an array*'
    }

    It 'Rejects authenticated output without exactly one verification result' -ForEach @(
        @{ Count = 0 }
        @{ Count = 2 }
    ) {
        $script:VerificationJson = if ($Count -eq 0) {
            '[]'
        }
        else {
            ConvertTo-Json -InputObject @($script:Fixture, $script:Fixture) -Depth 30 -Compress
        }

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*exactly one result*'
    }

    It 'Rejects a verification result with an unknown field' {
        $script:Fixture | Add-Member -NotePropertyName unexpected -NotePropertyValue 'value'
        $script:VerificationJson = ConvertTo-Json -InputObject @($script:Fixture) -Depth 30 -Compress

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*verification result has a missing or unknown field*'
    }

    It 'Rejects a statement without exactly one subject' -ForEach @(
        @{ Subjects = @() }
        @{ Subjects = @('duplicate') }
    ) {
        if ($Subjects.Count -eq 0) {
            $script:Fixture.verificationResult.statement.subject = @()
        }
        else {
            $Subject = $script:Fixture.verificationResult.statement.subject[0]
            $script:Fixture.verificationResult.statement.subject = @($Subject, $Subject)
        }
        $script:VerificationJson = ConvertTo-Json -InputObject @($script:Fixture) -Depth 30 -Compress

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw '*exactly one subject*'
    }

    It 'Rejects policy mismatch: <Name>' -ForEach @(
        @{
            Name   = 'predicate type'
            Error  = '*predicate type*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicateType = 'https://example.invalid/predicate' }
        }
        @{
            Name   = 'build type'
            Error  = '*build type*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.buildType = 'https://example.invalid/build' }
        }
        @{
            Name   = 'event name'
            Error  = '*event name*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.internalParameters.github.event_name = 'pull_request' }
        }
        @{
            Name   = 'runner environment'
            Error  = '*runner environment*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.internalParameters.github.runner_environment = 'self-hosted' }
        }
        @{
            Name   = 'repository identifier'
            Error  = '*repository_id must be a nonempty decimal identifier*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.internalParameters.github.repository_id = '' }
        }
        @{
            Name   = 'repository owner identifier'
            Error  = '*repository_owner_id must be a nonempty decimal identifier*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.internalParameters.github.repository_owner_id = 'owner' }
        }
        @{
            Name   = 'external workflow ref'
            Error  = '*external workflow ref*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.externalParameters.workflow.ref = 'refs/heads/main' }
        }
        @{
            Name   = 'external workflow repository'
            Error  = '*external workflow repository*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.externalParameters.workflow.repository = 'https://github.com/example/other' }
        }
        @{
            Name   = 'external workflow path'
            Error  = '*external workflow path*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.externalParameters.workflow.path = '.github/workflows/other.yml' }
        }
        @{
            Name   = 'unknown external workflow field'
            Error  = '*external workflow has a missing or unknown field*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.externalParameters.workflow | Add-Member -NotePropertyName input -NotePropertyValue 'untrusted' }
        }
        @{
            Name   = 'unknown internal field'
            Error  = '*internal GitHub parameters has a missing or unknown field*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.internalParameters.github | Add-Member -NotePropertyName actor -NotePropertyValue 'unexpected' }
        }
        @{
            Name   = 'resolved dependency count'
            Error  = '*resolved dependencies must contain exactly one entry*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.resolvedDependencies = @() }
        }
        @{
            Name   = 'resolved dependency URI'
            Error  = '*resolved dependency URI*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.resolvedDependencies[0].uri = 'git+https://github.com/example/other@refs/tags/v3.4.0' }
        }
        @{
            Name   = 'resolved dependency digest'
            Error  = '*resolved dependency digest*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.resolvedDependencies[0].digest.gitCommit = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' }
        }
        @{
            Name   = 'unknown resolved dependency digest'
            Error  = '*resolved dependency digest has a missing or unknown field*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.buildDefinition.resolvedDependencies[0].digest | Add-Member -NotePropertyName sha256 -NotePropertyValue 'unexpected' }
        }
        @{
            Name   = 'builder identity'
            Error  = '*builder identity*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.predicate.runDetails.builder.id = 'https://github.com/example/other/.github/workflows/release.yml@refs/heads/main' }
        }
        @{
            Name   = 'subject name'
            Error  = '*subject name*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.subject[0].name = 'other.vsix' }
        }
        @{
            Name   = 'subject digest'
            Error  = '*subject digest*'
            Mutate = { param($Fixture) $Fixture.verificationResult.statement.subject[0].digest.sha256 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' }
        }
    ) {
        & $Mutate $script:Fixture
        $script:VerificationJson = ConvertTo-Json -InputObject @($script:Fixture) -Depth 30 -Compress

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Throw $Error
    }

    It 'Retains ZIP and OpenVEX cryptographic verification without parsing sidecars' {
        $ZipPath = Join-Path $script:tempDir 'hve-core-plugin.zip'
        $VexPath = Join-Path $script:tempDir 'hve-core.openvex.json'
        $UnrelatedPath = Join-Path $script:tempDir 'unrelated.metadata.json'
        Set-Content -LiteralPath $ZipPath -Value 'zip bytes'
        Set-Content -LiteralPath $VexPath -Value '{"sanitized":true}'
        Set-Content -LiteralPath $UnrelatedPath -Value '{not-trusted}'

        {
            Invoke-ProvenanceVerification -ArtifactDirectory $script:tempDir -Repository $script:Repository -ExpectedSourceSha $script:SourceSha -ExpectedSignerSha $script:SignerSha -ReleaseTag $script:ReleaseTag
        } | Should -Not -Throw

        Should -Invoke Invoke-ExternalCommand -Times 3 -Exactly
        Should -Invoke Invoke-ExternalCommand -Times 1 -Exactly -ParameterFilter {
            $Command -eq 'gh' -and $Arguments[2] -eq [System.IO.Path]::GetFullPath($ZipPath) -and
            ($Arguments -join ' ') -eq "attestation verify $([System.IO.Path]::GetFullPath($ZipPath)) --repo $script:Repository"
        }
        Should -Invoke Invoke-ExternalCommand -Times 1 -Exactly -ParameterFilter {
            $Command -eq 'gh' -and $Arguments[2] -eq [System.IO.Path]::GetFullPath($VexPath) -and
            $Arguments -contains "$script:Repository/.github/workflows/vex-attest.yml" -and
            $Arguments -contains 'https://openvex.dev/ns/v0.2.0'
        }
    }
}
