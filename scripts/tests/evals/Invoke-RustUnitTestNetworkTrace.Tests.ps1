#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-RustUnitTestNetworkTrace.ps1'
    . $script:ScriptPath `
        -InputPath 'unused' `
        -ProvenancePath 'unused' `
        -Image 'ghcr.io/example/unused@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

    function New-RustTraceFixture {
        param(
            [Parameter(Mandatory = $true)][string]$Root,
            [Parameter(Mandatory = $false)][string]$Endpoint = 'http://127.0.0.1:4321'
        )

        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Root 'src') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Root 'vendor') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Root '.cargo') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $Root 'Cargo.toml') -Encoding utf8NoBOM -Value @'
[package]
name = "trace-fixture"
version = "0.1.0"
edition = "2021"
'@
        Set-Content -LiteralPath (Join-Path $Root 'Cargo.lock') -Encoding utf8NoBOM -Value '# locked'
        Set-Content -LiteralPath (Join-Path $Root 'vendor/.cargo-checksum.json') -Encoding utf8NoBOM -Value '{}'
        Set-Content -LiteralPath (Join-Path $Root '.cargo/config.toml') -Encoding utf8NoBOM -Value @'
[source.crates-io]
replace-with = "vendored-sources"
[source.vendored-sources]
directory = "vendor"
'@
        $rustSource = @(
            "const ENDPOINT: &str = `"$Endpoint`";",
            '',
            '#[cfg(test)]',
            'mod tests {}'
        ) -join "`n"
        Set-Content -LiteralPath (Join-Path $Root 'src/lib.rs') -Encoding utf8NoBOM -Value $rustSource
        return $Root
    }

    function New-TraceProvenance {
        param([Parameter(Mandatory = $true)][string]$Path)

        [ordered]@{
            stimulusId = 'rust-http-unit-test-isolation'
            model = 'test-model'
            generatedAt = '2026-09-05T12:00:00Z'
            transcriptPath = 'synthetic/transcript.json'
        } | ConvertTo-Json | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
        return $Path
    }

    function New-DockerStub {
        param(
            [Parameter(Mandatory = $true)][string]$Root,
            [Parameter(Mandatory = $false)][int]$InspectExitCode = 0,
            [Parameter(Mandatory = $false)][int]$RunExitCode = 0,
            [Parameter(Mandatory = $false)][int]$StartDelaySeconds = 0,
            [Parameter(Mandatory = $false)][int]$ContainerInspectExitCode = 1,
            [Parameter(Mandatory = $false)][string]$ImageRepoDigest = 'ghcr.io/example/rust-strace@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            [Parameter(Mandatory = $false)][bool]$WriteTrace = $true,
            [Parameter(Mandatory = $false)][string[]]$TraceLines = @(
                '1 connect(3, {sa_family=AF_INET, sin_port=htons(4321), sin_addr=inet_addr("127.0.0.1")}, 16) = 0'
            )
        )

        $stubPath = Join-Path $Root 'docker-stub.ps1'
        $argumentLog = Join-Path $Root 'docker-arguments.jsonl'
        Remove-Item -LiteralPath $argumentLog -Force -ErrorAction SilentlyContinue
        $escapedLog = $argumentLog.Replace("'", "''")
        $traceJson = $TraceLines | ConvertTo-Json -Compress
        $escapedTraceJson = $traceJson.Replace("'", "''")
        $stub = @"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$Remaining)
(`$Remaining | ConvertTo-Json -Compress) | Add-Content -LiteralPath '$escapedLog' -Encoding utf8
if (`$Remaining[0] -eq 'image' -and `$Remaining[1] -eq 'inspect') {
    Write-Output '[{"Id":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","RepoDigests":["$ImageRepoDigest"]}]'
    exit $InspectExitCode
}
if (`$Remaining[0] -eq 'create') { Write-Output 'synthetic-container-id'; exit 0 }
if (`$Remaining[0] -eq 'start') {
    if ($StartDelaySeconds -gt 0) { Start-Sleep -Seconds $StartDelaySeconds }
    Write-Output 'synthetic cargo output'
    exit $RunExitCode
}
if (`$Remaining[0] -eq 'kill') { exit 0 }
if (`$Remaining[0] -eq 'cp') {
    `$traceLines = '$escapedTraceJson' | ConvertFrom-Json
    if (`$$WriteTrace) {
        `$traceLines | Set-Content -LiteralPath `$Remaining[-1] -Encoding utf8NoBOM
        exit 0
    }
    exit 1
}
if (`$Remaining[0] -eq 'rm') { exit 0 }
if (`$Remaining[0] -eq 'container' -and `$Remaining[1] -eq 'inspect') { exit $ContainerInspectExitCode }
exit 9
"@
        Set-Content -LiteralPath $stubPath -Value $stub -Encoding utf8NoBOM
        return [pscustomobject]@{
            Path = $stubPath
            ArgumentLog = $argumentLog
        }
    }

    $script:Image = 'ghcr.io/example/rust-strace@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
}

Describe 'Invoke-RustUnitTestNetworkTrace.ps1' -Tag 'Unit' {
    BeforeEach {
        $script:FixtureRoot = Join-Path $TestDrive ([Guid]::NewGuid().ToString('N'))
        $script:RepoRoot = Join-Path $TestDrive ('repo-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:RepoRoot -Force | Out-Null
        $script:InputPath = New-RustTraceFixture -Root $script:FixtureRoot
        $script:ProvenancePath = New-TraceProvenance -Path (Join-Path $TestDrive ([Guid]::NewGuid().ToString('N') + '.json'))
        $script:OutputPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString('N') + '.json')
    }

    Context 'preview mode' {
        It 'validates inputs and returns hardened arguments without execution' {
            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -Preview

            $result.status | Should -Be 'Preview'
            $result.executed | Should -BeFalse
            $result.dockerArguments | Should -Contain 'none'
            $result.dockerArguments | Should -Contain 'SYS_PTRACE'
            ($result.dockerArguments -join ' ') | Should -Match 'cargo test --offline'
            Test-Path -LiteralPath $script:OutputPath | Should -BeFalse
        }

        It 'runs the script entry point without prompting for the default output path' {
            $output = & pwsh -NoProfile -File $script:ScriptPath `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -Preview

            $LASTEXITCODE | Should -Be 0
            ($output -join "`n") | Should -Match '"status": "Preview"'
        }
    }

    Context 'input validation' {
        It 'rejects an input inside the repository root' {
            $repoInput = New-RustTraceFixture -Root (Join-Path $script:RepoRoot 'generated')

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $repoInput `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -Preview
            } | Should -Throw '*outside the repository root*'
        }

        It 'rejects a crate without Cargo.lock' {
            Remove-Item -LiteralPath (Join-Path $script:InputPath 'Cargo.lock')

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $script:InputPath `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -Preview
            } | Should -Throw '*Cargo.lock*'
        }

        It 'rejects incomplete provenance' {
            @{ stimulusId = 'only-one-field' } | ConvertTo-Json |
                Set-Content -LiteralPath $script:ProvenancePath -Encoding utf8NoBOM

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $script:InputPath `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -Preview
            } | Should -Throw '*missing required property*'
        }

        It 'rejects a pre-existing report path' {
            Set-Content -LiteralPath $script:OutputPath -Value '{}' -Encoding utf8NoBOM

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $script:InputPath `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -Preview
            } | Should -Throw '*already exists*'
        }

        It 'rejects symbolic links in the disposable crate' {
            $link = Join-Path $script:InputPath 'src/linked.rs'
            try {
                New-Item -ItemType SymbolicLink -Path $link -Target (Join-Path $script:InputPath 'src/lib.rs') -ErrorAction Stop | Out-Null
            }
            catch {
                Set-ItResult -Skipped -Because 'symbolic-link creation is unavailable in this test environment'
                return
            }

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $script:InputPath `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -Preview
            } | Should -Throw '*symbolic links or reparse points*'
        }

        It 'rejects an input that exceeds its file cap' {
            {
                Assert-TraceInput `
                    -ResolvedInput $script:InputPath `
                    -ResolvedRepoRoot $script:RepoRoot `
                    -MaximumFiles 2
            } | Should -Throw '*file-count limit*'
        }

        It 'rejects endpoint evidence that exceeds its collection cap' {
            $inventory = @(Get-RustSourceInventory -Root $script:InputPath)

            {
                Get-LiteralEndpointEvidence `
                    -Root $script:InputPath `
                    -Inventory $inventory `
                    -MaximumEndpoints 0
            } | Should -Throw '*endpoint evidence exceeds*'
        }
    }

    Context 'contained command execution' {
        It 'passes a loopback-only fixture and cleans temporary mounts' {
            $stub = New-DockerStub -Root $TestDrive

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -NonAttesting

            $result.status | Should -Be 'NonAttesting'
            $result.cleanup | Should -Be 'Complete'
            $result.configuredContainment.network | Should -Be 'none'
            $result.testPlacement.unitTestFiles | Should -Contain 'src/lib.rs'
            $result.emptyNonLoopbackListIsProofOfLoopbackOnly | Should -BeFalse
            $result.networkAttempts[0].classification | Should -Be 'loopback'
            $result.evidenceMode | Should -Be 'non-attesting'
            $result.nonClaims | Should -HaveCount 4
            ($result.nonClaims -join ' ') | Should -Match 'untrusted generated data'

            $calls = @(Get-Content -LiteralPath $stub.ArgumentLog | ForEach-Object { $_ | ConvertFrom-Json -NoEnumerate })
            $create = @($calls | Where-Object { $_[0] -eq 'create' })[0]
            $create | Should -Contain 'none'
            $create | Should -Contain 'never'
            $create | Should -Contain 'ALL'
            $create | Should -Contain 'SYS_PTRACE'
            $create | Should -Contain 'SETUID'
            $create | Should -Contain 'SETGID'
            $create | Should -Contain '0:0'
            ($create -join ' ') | Should -Match 'no-new-privileges=true'
            $create | Should -Contain '--read-only'
            ($create -join ' ') | Should -Match 'dst=/workspace,readonly'
            ($create -join ' ') | Should -Not -Match 'type=bind[^ ]+dst=/trace'
            $create | Should -Contain '/trace:rw,noexec,nosuid,mode=0700,size=16m'
            $create | Should -Contain '/build:rw,noexec,nosuid,size=1g'
            $create | Should -Contain '--pids-limit'
            $create | Should -Contain '--memory'
            $create | Should -Contain '--cpus'
            ($create -join ' ') | Should -Match "ip link show lo .+ grep -q 'UP'"
            ($create -join ' ') | Should -Match 'CARGO_HOME=/tmp/cargo-home'
            ($create -join ' ') | Should -Match 'CARGO_TARGET_DIR=/build/target'
            ($create -join ' ') | Should -Match 'setpriv --reuid=1000 --regid=1000 --clear-groups'
            ($create -join ' ') | Should -Match 'cargo test --offline'

            @($calls | ForEach-Object { $_[0] }) | Should -Be @(
                'image', 'create', 'start', 'cp', 'rm', 'container'
            )

            $mounts = @($create | Where-Object { $_ -like 'type=bind,src=*' })
            foreach ($mount in $mounts) {
                $source = $mount -replace '^type=bind,src=(.*),dst=/[^,]+(?:,readonly)?$', '$1'
                Test-Path -LiteralPath $source | Should -BeFalse
            }
        }

        It 'reports external intent even when no non-loopback connect is observed' {
            Set-Content -LiteralPath (Join-Path $script:InputPath 'src/lib.rs') `
                -Value 'const ENDPOINT: &str = "https://example.com";' -Encoding utf8NoBOM
            $stub = New-DockerStub -Root $TestDrive

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -NonAttesting

            $result.status | Should -Be 'ConcernObserved'
            $result.literalEndpoints[0].classification | Should -Be 'external-intent'
            @($result.networkAttempts | Where-Object { $_.classification -eq 'non-loopback' }) | Should -HaveCount 0
            $result.emptyNonLoopbackListIsProofOfLoopbackOnly | Should -BeFalse
        }

        It 'propagates a failed test run without reporting a pass' {
            $stub = New-DockerStub -Root $TestDrive -RunExitCode 7

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -NonAttesting

            $result.status | Should -Be 'Failed'
            $result.test.exitCode | Should -Be 7
            $result.cleanup | Should -Be 'Complete'
        }

        It 'rejects an unavailable digest-pinned image before running the crate' {
            $stub = New-DockerStub -Root $TestDrive -InspectExitCode 1

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $script:InputPath `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -DockerExecutable 'pwsh' `
                    -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                    -NonAttesting
            } | Should -Throw '*not available locally*'
        }

        It 'fails when the container produces no strace evidence' {
            $stub = New-DockerStub -Root $TestDrive -WriteTrace $false

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $script:InputPath `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -DockerExecutable 'pwsh' `
                    -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                    -NonAttesting
            } | Should -Throw '*Trace evidence copy failed*'
        }

        It 'ignores endpoint URLs in vendored dependency source' {
            Set-Content -LiteralPath (Join-Path $script:InputPath 'vendor/dependency.rs') `
                -Value 'const DOCS: &str = "https://docs.rs/dependency";' -Encoding utf8NoBOM
            $stub = New-DockerStub -Root $TestDrive

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -NonAttesting

            $result.status | Should -Be 'NonAttesting'
            @($result.literalEndpoints | Where-Object { $_.host -eq 'docs.rs' }) | Should -HaveCount 0
        }

        It 'records integration-test placement and endpoint intent' {
            New-Item -ItemType Directory -Path (Join-Path $script:InputPath 'tests') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:InputPath 'tests/integration.rs') `
                -Value 'const ENDPOINT: &str = "https://integration.example";' -Encoding utf8NoBOM
            $stub = New-DockerStub -Root $TestDrive

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -NonAttesting

            $result.status | Should -Be 'ConcernObserved'
            $result.testPlacement.integrationTestFiles | Should -Contain 'tests/integration.rs'
            $endpoint = @($result.literalEndpoints | Where-Object { $_.host -eq 'integration.example' })[0]
            $endpoint.category | Should -Be 'integration'
        }

        It 'treats unresolved network attempts as concerns' {
            $stub = New-DockerStub -Root $TestDrive -TraceLines @(
                '1 connect(3, {sa_family=AF_UNIX, sun_path="/unknown"}, 16) = -1'
            )

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -NonAttesting

            $result.status | Should -Be 'ConcernObserved'
            $result.networkAttempts[0].classification | Should -Be 'unresolved'
        }
    }

    Context 'trace parsing' {
        It 'classifies DNS and non-loopback network attempts' {
            $tracePath = Join-Path $TestDrive 'strace.log'
            @(
                '1 sendto(3, "query", 5, 0, {sa_family=AF_INET, sin_port=htons(53), sin_addr=inet_addr("10.0.0.2")}, 16) = 5',
                '1 connect(4, {sa_family=AF_INET, sin_port=htons(443), sin_addr=inet_addr("203.0.113.10")}, 16) = -1 ENETUNREACH'
            ) | Set-Content -LiteralPath $tracePath -Encoding utf8NoBOM

            $attempts = @(Get-NetworkAttemptEvidence -TracePath $tracePath)

            $attempts | Should -HaveCount 2
            $attempts[0].classification | Should -Be 'dns'
            $attempts[1].classification | Should -Be 'non-loopback'
        }

        It 'joins split records and preserves unknown network evidence' {
            $tracePath = Join-Path $TestDrive 'split-strace.log'
            @(
                '44 connect(3, {sa_family=AF_INET, <unfinished ...>',
                '44 <... connect resumed> sin_port=htons(4321), sin_addr=inet_addr("127.0.0.1")}, 16) = 0',
                '45 sendmmsg ???'
            ) | Set-Content -LiteralPath $tracePath -Encoding utf8NoBOM

            $attempts = @(Get-NetworkAttemptEvidence -TracePath $tracePath)

            $attempts | Should -HaveCount 2
            $attempts[0].classification | Should -Be 'loopback'
            $attempts[1].classification | Should -Be 'unknown'
        }

        It 'records trace and attempt bounds as unknown evidence' {
            $tracePath = Join-Path $TestDrive 'bounded-strace.log'
            @(
                '1 socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 3',
                '1 connect(3, {sa_family=AF_INET, sin_port=htons(80), sin_addr=inet_addr("127.0.0.1")}, 16) = 0'
            ) | Set-Content -LiteralPath $tracePath -Encoding utf8NoBOM

            @(Get-NetworkAttemptEvidence -TracePath $tracePath -MaximumLines 1)[-1].classification | Should -Be 'unknown'
            @(Get-NetworkAttemptEvidence -TracePath $tracePath -MaximumAttempts 1)[-1].classification | Should -Be 'unknown'
        }
    }

    Context 'bounded process execution' {
        It 'selects one executable when command discovery returns duplicate paths' {
            Mock Get-Command {
                @(
                    [pscustomobject]@{ Source = '/usr/bin/pwsh' },
                    [pscustomobject]@{ Source = '/bin/pwsh' }
                )
            } -ParameterFilter { $Name -eq 'pwsh' }

            Resolve-TraceExecutable -Name 'pwsh' | Should -Be '/usr/bin/pwsh'
        }

        It 'terminates a process that exceeds the timeout' {
            $result = Invoke-BoundedProcess `
                -Executable 'pwsh' `
                -Arguments @('-NoProfile', '-Command', 'while ($true) {}') `
                -TimeoutSeconds 1

            $result.TimedOut | Should -BeTrue
            $result.ExitCode | Should -Be -1
        }

        It 'bounds and sanitizes process output while draining streams' {
            $result = Invoke-BoundedProcess `
                -Executable 'pwsh' `
                -Arguments @('-NoProfile', '-Command', '[Console]::Out.Write(("a" * 40) + [char]1)') `
                -TimeoutSeconds 5 `
                -MaximumOutputCharacters 10

            $result.StandardOutput | Should -BeLike 'aaaaaaaaaa*truncated*'
            $result.StandardOutput | Should -Not -Match "`u{1}"
        }
    }

    Context 'attestation and lifecycle gates' {
        It 'rejects an undeclared deterministic Docker seam' {
            $stub = New-DockerStub -Root $TestDrive

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $script:InputPath `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -DockerExecutable 'pwsh' `
                    -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path)
            } | Should -Throw '*require -NonAttesting*'
        }

        It 'rejects an inspected image that does not match the requested digest' {
            $stub = New-DockerStub -Root $TestDrive `
                -ImageRepoDigest 'ghcr.io/example/other@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'

            {
                Invoke-RustUnitTestNetworkTrace `
                    -InputPath $script:InputPath `
                    -ProvenancePath $script:ProvenancePath `
                    -Image $script:Image `
                    -OutputPath $script:OutputPath `
                    -RepoRoot $script:RepoRoot `
                    -ContainerUser '1000:1000' `
                    -DockerExecutable 'pwsh' `
                    -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                    -NonAttesting
            } | Should -Throw '*did not verify the requested digest*'
        }

        It 'kills a timed-out named container before copying and removing it' {
            $stub = New-DockerStub -Root $TestDrive -StartDelaySeconds 2

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -TimeoutSeconds 1 `
                -NonAttesting

            $result.status | Should -Be 'Failed'
            $calls = @(Get-Content -LiteralPath $stub.ArgumentLog | ForEach-Object { ($_ | ConvertFrom-Json -NoEnumerate)[0] })
            $calls | Should -Be @('image', 'create', 'start', 'kill', 'cp', 'rm', 'container')
        }

        It 'retains host evidence and reports Inconclusive when absence is unconfirmed' {
            $stub = New-DockerStub -Root $TestDrive -ContainerInspectExitCode 0

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -NonAttesting

            $result.status | Should -Be 'Inconclusive'
            $result.cleanup | Should -Be 'Unconfirmed'
            Test-Path -LiteralPath $result.retainedEvidencePath | Should -BeTrue
            Remove-Item -LiteralPath $result.retainedEvidencePath -Recurse -Force
        }
    }

    Context 'source inventory and publication' {
        It 'classifies nested workspace source and excludes vendor and target trees' {
            New-Item -ItemType Directory -Path (Join-Path $script:InputPath 'crates/member/examples') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:InputPath 'crates/member/benches') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:InputPath 'target/debug') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:InputPath 'build.rs') -Value 'fn main() {}' -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $script:InputPath 'crates/member/examples/example.rs') -Value 'fn main() {}' -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $script:InputPath 'crates/member/benches/bench.rs') -Value 'fn main() {}' -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $script:InputPath 'target/debug/generated.rs') -Value 'fn ignored() {}' -Encoding utf8NoBOM

            $inventory = @(Get-RustSourceInventory -Root $script:InputPath)

            @($inventory.category) | Should -Contain 'build'
            @($inventory.category) | Should -Contain 'example'
            @($inventory.category) | Should -Contain 'bench'
            @($inventory.path) | Should -Not -Contain 'target/debug/generated.rs'
        }

        It 'reports Inconclusive when no generated Rust source is discovered' {
            Remove-Item -LiteralPath (Join-Path $script:InputPath 'src') -Recurse -Force
            $stub = New-DockerStub -Root $TestDrive

            $result = Invoke-RustUnitTestNetworkTrace `
                -InputPath $script:InputPath `
                -ProvenancePath $script:ProvenancePath `
                -Image $script:Image `
                -OutputPath $script:OutputPath `
                -RepoRoot $script:RepoRoot `
                -ContainerUser '1000:1000' `
                -DockerExecutable 'pwsh' `
                -DockerPrefixArguments @('-NoProfile', '-File', $stub.Path) `
                -NonAttesting

            $result.status | Should -Be 'Inconclusive'
            $result.testPlacement.sourceInventory | Should -HaveCount 0
        }

        It 'publishes reports without overwriting an existing path' {
            Write-TraceJson -Report @{ status = 'first' } -Path $script:OutputPath

            { Write-TraceJson -Report @{ status = 'second' } -Path $script:OutputPath } | Should -Throw
            (Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json).status | Should -Be 'first'
        }
    }

    Context 'registered evidence contracts' {
        It 'registers the operator lane as noninteractive' {
            $package = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../../package.json') -Raw | ConvertFrom-Json

            $package.scripts.'ci:test:rust-network-isolation' | Should -Match 'pwsh -NoProfile -NonInteractive -File'
        }

        It 'matches wrapped network-boundary guidance' {
            $pattern = '(?i)(must\s+not|do\s+not|avoid|prohibit)[\s\S]{0,80}(DNS|non-loopback)|(DNS|non-loopback)[\s\S]{0,80}(must\s+not|do\s+not|avoid|prohibit)'

            "Unit tests must not make`nDNS requests." | Should -Match $pattern
        }
    }
}
