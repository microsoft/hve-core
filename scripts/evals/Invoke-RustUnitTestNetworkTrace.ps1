#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Runs a prepared Rust crate under network-denied containment.
.DESCRIPTION
    Validates a disposable, provenance-bearing Rust crate with vendored
    dependencies, copies it to an isolated temporary root, and runs
    `cargo test --offline` in a locally present digest-pinned Docker image.
    Docker uses no network, and strace records resolver and socket attempts.
.PARAMETER InputPath
    Disposable generated Rust crate. It must be outside the repository and
    contain Cargo.toml, Cargo.lock, vendor/, and .cargo/config.toml.
.PARAMETER ProvenancePath
    JSON file containing stimulusId, model, generatedAt, and transcriptPath.
.PARAMETER Image
    Locally present trace image in name@sha256:<digest> form.
.PARAMETER OutputPath
    Destination for the machine-readable JSON report.
.PARAMETER RepoRoot
    Repository root used to reject canonical source inputs.
.PARAMETER DockerExecutable
    Docker executable or test stub to invoke.
.PARAMETER DockerPrefixArguments
    Arguments placed before Docker arguments, used by deterministic tests.
.PARAMETER NonAttesting
    Permits deterministic executable seams but prevents an attesting pass.
.PARAMETER ContainerUser
    Linux numeric user and group in UID:GID form. When omitted on Linux, the
    script resolves the current values with `id`.
.PARAMETER TimeoutSeconds
    Maximum duration of each Docker operation.
.PARAMETER Preview
    Validate inputs and print the planned Docker arguments without execution.
.EXAMPLE
    ./scripts/evals/Invoke-RustUnitTestNetworkTrace.ps1 `
        -InputPath ../generated-rust-case `
        -ProvenancePath ../generated-rust-case.provenance.json `
        -Image ghcr.io/example/rust-strace@sha256:<digest>
.NOTES
    Runs via: npm run ci:test:rust-network-isolation -- <arguments>
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProvenancePath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^\s@]+@sha256:[a-fA-F0-9]{64}$')]
    [string]$Image,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/rust-unit-test-network-trace.json',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$DockerExecutable = 'docker',

    [Parameter(Mandatory = $false)]
    [string[]]$DockerPrefixArguments = @(),

    [Parameter(Mandatory = $false)]
    [switch]$NonAttesting,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d+:\d+$')]
    [string]$ContainerUser,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 300,

    [Parameter(Mandatory = $false)]
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'

#region Functions

function Resolve-RequiredPath {
    <#
    .SYNOPSIS
        Resolves an existing filesystem path.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Container', 'Leaf')]
        [string]$PathType
    )

    if (-not (Test-Path -LiteralPath $Path -PathType $PathType)) {
        throw "Required $PathType path does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Test-PathWithinRoot {
    <#
    .SYNOPSIS
        Tests whether a path is within a root directory.
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $rootWithSeparator = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    return $Path.Equals($Root, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)
}

function Get-RepositoryRoot {
    <#
    .SYNOPSIS
        Resolves the configured or current Git repository root.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $false)][string]$Override)

    if ($Override) {
        return Resolve-RequiredPath -Path $Override -PathType Container
    }

    $root = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw 'Unable to resolve the repository root. Pass -RepoRoot explicitly.'
    }
    return (Resolve-Path -LiteralPath $root.Trim()).Path
}

function Assert-TraceInput {
    <#
    .SYNOPSIS
        Validates the disposable crate boundary and offline inputs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedInput,
        [Parameter(Mandatory = $true)][string]$ResolvedRepoRoot,
        [Parameter(Mandatory = $false)][int]$MaximumFiles = 10000,
        [Parameter(Mandatory = $false)][long]$MaximumBytes = 536870912
    )

    $rootItem = Get-Item -LiteralPath $ResolvedInput -Force
    if ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'InputPath root must not be a symbolic link or reparse point.'
    }
    if (Test-PathWithinRoot -Path $ResolvedInput -Root $ResolvedRepoRoot) {
        throw 'InputPath must be a disposable crate outside the repository root.'
    }

    $reparsePoints = @(Get-ChildItem -LiteralPath $ResolvedInput -Force -Recurse |
        Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
    if ($reparsePoints.Count -gt 0) {
        throw "InputPath must not contain symbolic links or reparse points: $($reparsePoints[0].FullName)"
    }

    foreach ($required in @('Cargo.toml', 'Cargo.lock')) {
        if (-not (Test-Path -LiteralPath (Join-Path $ResolvedInput $required) -PathType Leaf)) {
            throw "InputPath is missing required offline file: $required"
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $ResolvedInput 'vendor') -PathType Container)) {
        throw 'InputPath is missing required vendored dependencies: vendor/'
    }
    $files = @(Get-ChildItem -LiteralPath $ResolvedInput -File -Force -Recurse)
    if ($files.Count -gt $MaximumFiles) {
        throw "InputPath exceeds the file-count limit of $MaximumFiles."
    }
    $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
    if ($totalBytes -gt $MaximumBytes) {
        throw "InputPath exceeds the byte limit of $MaximumBytes."
    }
    if (-not (Get-ChildItem -LiteralPath (Join-Path $ResolvedInput 'vendor') -File -Force -Recurse | Select-Object -First 1)) {
        throw 'InputPath vendor directory must contain vendored dependency files.'
    }
}

function Get-TraceInputManifest {
    <#
    .SYNOPSIS
        Creates a content manifest for a bounded input tree.
    .OUTPUTS
        System.Object[]
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory = $true)][string]$Root)

    return @(Get-ChildItem -LiteralPath $Root -File -Force -Recurse |
        Sort-Object -Property FullName |
        ForEach-Object {
            [ordered]@{
                path = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
                length = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        })
}

function New-CapturedTraceInput {
    <#
    .SYNOPSIS
        Copies and validates an immutable execution input.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedInput,
        [Parameter(Mandatory = $true)][string]$ResolvedRepoRoot,
        [Parameter(Mandatory = $false)][int]$MaximumFiles = 10000,
        [Parameter(Mandatory = $false)][long]$MaximumBytes = 536870912
    )

    Assert-TraceInput -ResolvedInput $ResolvedInput -ResolvedRepoRoot $ResolvedRepoRoot -MaximumFiles $MaximumFiles -MaximumBytes $MaximumBytes
    $before = Get-TraceInputManifest -Root $ResolvedInput
    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("rust-network-trace-" + [Guid]::NewGuid().ToString('N'))
    $inputCopy = Join-Path $temporaryRoot 'input'
    try {
        New-Item -ItemType Directory -Path $inputCopy -Force | Out-Null
        Get-ChildItem -LiteralPath $ResolvedInput -Force |
            Copy-Item -Destination $inputCopy -Recurse -Force
        $after = Get-TraceInputManifest -Root $ResolvedInput
        $captured = Get-TraceInputManifest -Root $inputCopy
        if (($before | ConvertTo-Json -Depth 4 -Compress) -cne ($after | ConvertTo-Json -Depth 4 -Compress) -or
            ($before | ConvertTo-Json -Depth 4 -Compress) -cne ($captured | ConvertTo-Json -Depth 4 -Compress)) {
            throw 'InputPath changed while it was being captured.'
        }
        Assert-TraceInput -ResolvedInput $inputCopy -ResolvedRepoRoot $ResolvedRepoRoot -MaximumFiles $MaximumFiles -MaximumBytes $MaximumBytes
        $cargoDirectory = Join-Path $inputCopy '.cargo'
        if (Test-Path -LiteralPath $cargoDirectory) {
            Remove-Item -LiteralPath $cargoDirectory -Recurse -Force
        }
        New-Item -ItemType Directory -Path $cargoDirectory -Force | Out-Null
        @'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"

[net]
offline = true
'@ | Set-Content -LiteralPath (Join-Path $cargoDirectory 'config.toml') -Encoding utf8NoBOM
        return [pscustomobject]@{
            Root = $temporaryRoot
            Input = $inputCopy
            Manifest = @(Get-TraceInputManifest -Root $inputCopy)
        }
    }
    catch {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Read-TraceProvenance {
    <#
    .SYNOPSIS
        Reads and validates generated-crate provenance.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $provenance = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
    }
    catch {
        throw "ProvenancePath is not valid JSON: $($_.Exception.Message)"
    }

    foreach ($property in @('stimulusId', 'model', 'generatedAt', 'transcriptPath')) {
        if ([string]::IsNullOrWhiteSpace([string]$provenance.$property)) {
            throw "ProvenancePath is missing required property: $property"
        }
    }
    try {
        [void][DateTimeOffset]::Parse([string]$provenance.generatedAt)
    }
    catch {
        throw 'ProvenancePath generatedAt must be a valid date-time.'
    }
    return $provenance
}

function Get-RustSourceInventory {
    <#
    .SYNOPSIS
        Discovers relevant generated Rust files across crate and workspace layouts.
    .OUTPUTS
        System.Object[]
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $false)][int]$MaximumFiles = 2000
    )

    $files = @(Get-ChildItem -LiteralPath $Root -Filter '*.rs' -File -Force -Recurse |
        Where-Object {
            $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
            $relative -notmatch '(^|/)(vendor|target)(/|$)'
        } |
        Sort-Object -Property FullName)
    if ($files.Count -gt $MaximumFiles) {
        throw "Generated Rust source inventory exceeds the limit of $MaximumFiles files."
    }

    return @($files | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
        $category = if ($relative -match '(^|/)build\.rs$') { 'build' }
        elseif ($relative -match '(^|/)tests/') { 'integration' }
        elseif ($relative -match '(^|/)examples/') { 'example' }
        elseif ($relative -match '(^|/)benches/') { 'bench' }
        else { 'source' }
        [ordered]@{ path = $relative; category = $category }
    })
}

function Get-LiteralEndpointEvidence {
    <#
    .SYNOPSIS
        Extracts literal HTTP endpoints from generated Rust source.
    .OUTPUTS
        System.Object[]
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Inventory,
        [Parameter(Mandatory = $false)][int]$MaximumEndpoints = 2000
    )

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($source in $Inventory) {
        $text = Get-Content -LiteralPath (Join-Path $Root $source.path) -Raw -Encoding utf8
        foreach ($match in [regex]::Matches($text, '(?:r#*)?"(https?://[^"]+)"#*')) {
            if ($results.Count -ge $MaximumEndpoints) {
                throw "Literal endpoint evidence exceeds the limit of $MaximumEndpoints records."
            }
            $value = $match.Groups[1].Value
            try {
                $uri = [Uri]$value
                $loopback = $uri.IsLoopback -or $uri.Host -eq 'localhost'
                $results.Add([ordered]@{
                    value = $value
                    host = $uri.Host
                    classification = if ($loopback) { 'loopback' } else { 'external-intent' }
                    file = $source.path
                    category = $source.category
                })
            }
            catch {
                $results.Add([ordered]@{
                    value = $value
                    host = $null
                    classification = 'unparseable'
                    file = $source.path
                    category = $source.category
                })
            }
        }
    }
    return @($results)
}

function Get-TestPlacementEvidence {
    <#
    .SYNOPSIS
        Inventories source-file unit-test modules and integration-test files.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Inventory
    )

    $unitFiles = @($Inventory | Where-Object {
        $_.category -eq 'source' -and
        (Get-Content -LiteralPath (Join-Path $Root $_.path) -Raw -Encoding utf8) -match '#\s*\[cfg\s*\(\s*test\s*\)\s*\]'
    } | ForEach-Object { $_.path })
    $integrationFiles = @($Inventory | Where-Object { $_.category -eq 'integration' } | ForEach-Object { $_.path })

    return [pscustomobject]@{
        unitTestFiles = @($unitFiles)
        integrationTestFiles = @($integrationFiles)
        sourceInventory = @($Inventory)
    }
}

function New-DockerTraceArguments {
    <#
    .SYNOPSIS
        Builds hardened Docker arguments for the contained trace.
    .OUTPUTS
        System.String[]
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)][string]$InputCopy,
        [Parameter(Mandatory = $true)][string]$Image,
        [Parameter(Mandatory = $true)][string]$ContainerUser,
        [Parameter(Mandatory = $true)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_.-]+$')][string]$ContainerName,
        [Parameter(Mandatory = $true)][ValidatePattern('^[a-f0-9]{32}$')][string]$TraceId
    )

    foreach ($path in @($InputCopy)) {
        if (-not [IO.Path]::IsPathFullyQualified($path) -or $path.Contains(',')) {
            throw "Docker bind source must be absolute and must not contain commas: $path"
        }
    }

    $userParts = $ContainerUser -split ':', 2
    if ($userParts.Count -ne 2 -or $userParts[0] -notmatch '^\d+$' -or $userParts[1] -notmatch '^\d+$' -or $userParts[0] -eq '0') {
        throw 'ContainerUser must be a non-root numeric Linux UID:GID.'
    }
    $command = "set -eu; ip link show lo | grep -q 'UP'; strace -f -e trace=network -s 256 -o /trace/strace.log setpriv --reuid=$($userParts[0]) --regid=$($userParts[1]) --clear-groups --inh-caps=-all --ambient-caps=-all --bounding-set=-all cargo test --offline"
    return @(
        'create', '--name', $ContainerName, '--label', "hve.rust-network-trace=$TraceId",
        '--pull', 'never', '--network', 'none',
        '--cap-drop', 'ALL', '--cap-add', 'SYS_PTRACE', '--cap-add', 'SETUID', '--cap-add', 'SETGID',
        '--security-opt', 'no-new-privileges=true', '--read-only',
        '--user', '0:0',
        '--pids-limit', '256', '--memory', '1g', '--memory-swap', '1g', '--cpus', '2',
        '--ulimit', 'nofile=1024:1024',
        '--tmpfs', '/trace:rw,noexec,nosuid,mode=0700,size=16m',
        '--tmpfs', '/build:rw,noexec,nosuid,size=1g',
        '--tmpfs', '/tmp:rw,noexec,nosuid,size=64m',
        '--env', 'CARGO_HOME=/tmp/cargo-home',
        '--env', 'CARGO_TARGET_DIR=/build/target',
        '--mount', "type=bind,src=$InputCopy,dst=/workspace,readonly",
        '--workdir', '/workspace', $Image, 'sh', '-c', $command
    )
}

function Invoke-BoundedProcess {
    <#
    .SYNOPSIS
        Runs an external command without shell re-parsing and enforces a timeout.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $false)][int]$MaximumOutputCharacters = 16384
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    foreach ($argument in $Arguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    if (-not ('Hve.Evals.BoundedProcessRunner' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace Hve.Evals
{
    public sealed class BoundedProcessResult
    {
        public int ExitCode { get; set; }
        public bool TimedOut { get; set; }
        public string StandardOutput { get; set; }
        public string StandardError { get; set; }
    }

    public static class BoundedProcessRunner
    {
        private static async Task<string> DrainAsync(StreamReader reader, int maximumCharacters)
        {
            var buffer = new char[4096];
            var retained = new StringBuilder(maximumCharacters);
            var truncated = false;
            int read;
            while ((read = await reader.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false)) > 0)
            {
                var remaining = maximumCharacters - retained.Length;
                if (remaining > 0)
                {
                    retained.Append(buffer, 0, Math.Min(read, remaining));
                }
                if (read > remaining)
                {
                    truncated = true;
                }
            }
            if (truncated)
            {
                retained.Append("\n[truncated]");
            }
            return retained.ToString();
        }

        public static BoundedProcessResult Run(ProcessStartInfo startInfo, int timeoutMilliseconds, int maximumCharacters)
        {
            using (var process = new Process())
            {
                process.StartInfo = startInfo;
                if (!process.Start())
                {
                    throw new InvalidOperationException("Failed to start executable: " + startInfo.FileName);
                }
                var stdout = DrainAsync(process.StandardOutput, maximumCharacters);
                var stderr = DrainAsync(process.StandardError, maximumCharacters);
                var timedOut = !process.WaitForExit(timeoutMilliseconds);
                if (timedOut)
                {
                    try { process.Kill(true); } catch { }
                }
                process.WaitForExit();
                Task.WaitAll(stdout, stderr);
                return new BoundedProcessResult
                {
                    ExitCode = timedOut ? -1 : process.ExitCode,
                    TimedOut = timedOut,
                    StandardOutput = stdout.Result,
                    StandardError = stderr.Result
                };
            }
        }
    }
}
'@
    }
    $result = [Hve.Evals.BoundedProcessRunner]::Run($startInfo, $TimeoutSeconds * 1000, $MaximumOutputCharacters)
    return [pscustomobject]@{
        ExitCode = $result.ExitCode
        TimedOut = $result.TimedOut
        StandardOutput = Limit-TraceText -Value $result.StandardOutput -MaximumCharacters ($MaximumOutputCharacters + 12)
        StandardError = Limit-TraceText -Value $result.StandardError -MaximumCharacters ($MaximumOutputCharacters + 12)
    }
}

function Get-NetworkAttemptEvidence {
    <#
    .SYNOPSIS
        Parses strace network records into destination evidence.
    .OUTPUTS
        System.Object[]
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)][string]$TracePath,
        [Parameter(Mandatory = $false)][int]$MaximumLines = 100000,
        [Parameter(Mandatory = $false)][int]$MaximumAttempts = 10000
    )

    if (-not (Test-Path -LiteralPath $TracePath -PathType Leaf)) {
        throw "Expected strace output was not produced: $TracePath"
    }

    $attempts = [System.Collections.Generic.List[object]]::new()
    $unfinished = @{}
    $lineCount = 0
    $networkCalls = 'socket|connect|bind|sendto|sendmsg|sendmmsg|recvfrom|recvmsg'
    foreach ($line in Get-Content -LiteralPath $TracePath -Encoding utf8) {
        $lineCount++
        if ($lineCount -gt $MaximumLines) {
            $attempts.Add([ordered]@{ operation = 'trace-limit'; address = $null; port = $null; classification = 'unknown' })
            break
        }
        $record = $line
        if ($record -match "^(?<prefix>.*?)(?<operation>$networkCalls)\((?<body>.*)<unfinished \.\.\.>$") {
            $key = "$($Matches.prefix)|$($Matches.operation)"
            $unfinished[$key] = $record -replace '<unfinished \.\.\.>$', ''
            continue
        }
        if ($record -match "^(?<prefix>.*?)<\.\.\. (?<operation>$networkCalls) resumed>(?<body>.*)$") {
            $key = "$($Matches.prefix)|$($Matches.operation)"
            if ($unfinished.ContainsKey($key)) {
                $record = $unfinished[$key] + $Matches.body
                $unfinished.Remove($key)
            }
        }
        if ($record -notmatch "\b($networkCalls)\(") {
            if ($record -match "\b($networkCalls)\b") {
                $attempts.Add([ordered]@{ operation = $Matches[1]; address = $null; port = $null; classification = 'unknown' })
            }
            continue
        }
        if ($attempts.Count -ge $MaximumAttempts) {
            $attempts.Add([ordered]@{ operation = 'attempt-limit'; address = $null; port = $null; classification = 'unknown' })
            break
        }
        $operation = $Matches[1]
        $address = $null
        if ($record -match 'inet_addr\("([^\"]+)"\)') { $address = $Matches[1] }
        elseif ($record -match 'inet_pton\(AF_INET6, "([^\"]+)"') { $address = $Matches[1] }
        elseif ($record -match 'sin6?_addr=(?:in6_addr\()?"?([^",}\)]+)') { $address = $Matches[1] }
        $port = if ($record -match 'sin6?_port=htons\((\d+)\)') { [int]$Matches[1] } else { $null }

        $classification = if ($operation -eq 'socket') { 'metadata' } else { 'unresolved' }
        if ($port -eq 53) {
            $classification = 'dns'
        }
        elseif ($address) {
            try {
                $ip = [Net.IPAddress]::Parse($address)
                $classification = if ([Net.IPAddress]::IsLoopback($ip)) { 'loopback' } else { 'non-loopback' }
            }
            catch { $classification = 'unparseable' }
        }

        $attempts.Add([ordered]@{
            operation = $operation
            address = $address
            port = $port
            classification = $classification
        })
    }
    foreach ($entry in $unfinished.GetEnumerator()) {
        $attempts.Add([ordered]@{ operation = ($entry.Key -split '\|')[-1]; address = $null; port = $null; classification = 'unknown' })
    }
    return @($attempts)
}

function Get-ContainerUser {
    <#
    .SYNOPSIS
        Resolves the numeric Linux UID:GID used by the container.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $false)][string]$Override)

    if ($Override) { return $Override }
    if ($IsWindows) {
        throw 'ContainerUser is required when the host cannot resolve Linux UID:GID values.'
    }

    $uid = (& id -u 2>$null)
    if ($LASTEXITCODE -ne 0 -or $uid -notmatch '^\d+$') { throw 'Unable to resolve the current Linux UID.' }
    $gid = (& id -g 2>$null)
    if ($LASTEXITCODE -ne 0 -or $gid -notmatch '^\d+$') { throw 'Unable to resolve the current Linux GID.' }
    return "$uid`:$gid"
}

function Resolve-TraceExecutable {
    <#
    .SYNOPSIS
        Resolves one executable path in command-discovery order.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = @(Get-Command -Name $Name -CommandType Application, ExternalScript -ErrorAction Stop)[0]
    if (-not $command -or [string]::IsNullOrWhiteSpace([string]$command.Source)) {
        throw "Executable did not resolve to a usable path: $Name"
    }
    return [string]$command.Source
}

function Limit-TraceText {
    <#
    .SYNOPSIS
        Bounds captured process output for the JSON report.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory = $false)][int]$MaximumCharacters = 16384
    )

    if ($null -eq $Value) { return $Value }
    $safeValue = [regex]::Replace($Value, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '?')
    if ($safeValue.Length -le $MaximumCharacters) { return $safeValue }
    return $safeValue.Substring(0, $MaximumCharacters) + "`n[truncated]"
}

function Write-TraceJson {
    <#
    .SYNOPSIS
        Writes a trace report as UTF-8 JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try {
            $writer.Write(($Report | ConvertTo-Json -Depth 10))
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-RustUnitTestNetworkTrace {
    <#
    .SYNOPSIS
        Validates inputs and runs or previews the contained Rust test trace.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$ProvenancePath,
        [Parameter(Mandatory = $true)][string]$Image,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $false)][string]$RepoRoot,
        [Parameter(Mandatory = $false)][string]$DockerExecutable = 'docker',
        [Parameter(Mandatory = $false)][string[]]$DockerPrefixArguments = @(),
        [Parameter(Mandatory = $false)][switch]$NonAttesting,
        [Parameter(Mandatory = $false)][string]$ContainerUser,
        [Parameter(Mandatory = $false)][int]$TimeoutSeconds = 300,
        [Parameter(Mandatory = $false)][switch]$Preview
    )

    $resolvedInput = Resolve-RequiredPath -Path $InputPath -PathType Container
    $resolvedProvenance = Resolve-RequiredPath -Path $ProvenancePath -PathType Leaf
    $resolvedRepo = Get-RepositoryRoot -Override $RepoRoot
    $isDefaultDocker = $DockerExecutable -eq 'docker' -and $DockerPrefixArguments.Count -eq 0
    if (-not $Preview -and -not $NonAttesting -and -not $isDefaultDocker) {
        throw 'Alternate Docker executables or prefix arguments require -NonAttesting.'
    }
    if (-not $Preview -and -not $NonAttesting -and -not $IsLinux) {
        throw 'Attesting execution requires a Linux host.'
    }
    $resolvedDockerExecutable = Resolve-TraceExecutable -Name $DockerExecutable
    $provenance = Read-TraceProvenance -Path $resolvedProvenance
    $resolvedContainerUser = Get-ContainerUser -Override $ContainerUser
    if (Test-Path -LiteralPath $OutputPath) {
        throw "OutputPath already exists: $OutputPath"
    }

    $capture = New-CapturedTraceInput -ResolvedInput $resolvedInput -ResolvedRepoRoot $resolvedRepo
    $capturedInput = $capture.Input
    $reportProvenance = [ordered]@{
        stimulusId = [string]$provenance.stimulusId
        model = [string]$provenance.model
        generatedAt = [string]$provenance.generatedAt
        transcriptPath = [string]$provenance.transcriptPath
    }
    try {
        $sourceInventory = @(Get-RustSourceInventory -Root $capturedInput)
        $endpoints = @(Get-LiteralEndpointEvidence -Root $capturedInput -Inventory $sourceInventory)
        $testPlacement = Get-TestPlacementEvidence -Root $capturedInput -Inventory $sourceInventory
        $lockHash = (Get-FileHash -LiteralPath (Join-Path $capturedInput 'Cargo.lock') -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    catch {
        Remove-Item -LiteralPath $capture.Root -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }

    if ($Preview) {
        $previewInput = Join-Path ([IO.Path]::GetTempPath()) 'isolated-input'
        $arguments = New-DockerTraceArguments `
            -InputCopy $previewInput `
            -Image $Image `
            -ContainerUser $resolvedContainerUser `
            -ContainerName 'hve-rust-trace-preview' `
            -TraceId '00000000000000000000000000000000'
        $previewResult = [pscustomobject]@{
            status = 'Preview'
            executed = $false
            image = $Image
            evidenceMode = 'preview'
            dockerExecutable = $resolvedDockerExecutable
            cargoLockSha256 = $lockHash
            inputManifest = $capture.Manifest
            provenance = $reportProvenance
            literalEndpoints = $endpoints
            testPlacement = $testPlacement
            dockerArguments = @($DockerPrefixArguments) + $arguments
            nonClaims = @('No container or Rust test executed.', 'No runtime or harm conclusion is supported.')
        }
        Remove-Item -LiteralPath $capture.Root -Recurse -Force -ErrorAction SilentlyContinue
        return $previewResult
    }

    $temporaryRoot = $capture.Root
    $inputCopy = $capturedInput
    $traceOutput = Join-Path $temporaryRoot 'output'
    $tracePath = Join-Path $traceOutput 'strace.log'
    $traceId = [Guid]::NewGuid().ToString('N')
    $containerName = "hve-rust-trace-$traceId"
    $containerCreated = $false
    $containerAbsent = $false
    $retainTemporary = $false
    $lifecycle = [System.Collections.Generic.List[object]]::new()
    $cleanup = 'Pending'
    $report = $null
    try {
        New-Item -ItemType Directory -Path $traceOutput -Force | Out-Null

        $inspect = Invoke-BoundedProcess -Executable $resolvedDockerExecutable -Arguments (@($DockerPrefixArguments) + @('image', 'inspect', $Image)) -TimeoutSeconds $TimeoutSeconds
        if ($inspect.TimedOut -or $inspect.ExitCode -ne 0) {
            throw "Digest-pinned image is not available locally: $Image"
        }
        try {
            $imageInspection = @($inspect.StandardOutput | ConvertFrom-Json)[0]
        }
        catch {
            throw 'Docker image inspection did not return valid JSON identity evidence.'
        }
        if (-not $imageInspection.Id -or $Image -notin @($imageInspection.RepoDigests)) {
            throw "Docker image inspection did not verify the requested digest: $Image"
        }

        $dockerArguments = New-DockerTraceArguments -InputCopy $inputCopy -Image $Image -ContainerUser $resolvedContainerUser -ContainerName $containerName -TraceId $traceId
        $create = Invoke-BoundedProcess -Executable $resolvedDockerExecutable -Arguments (@($DockerPrefixArguments) + $dockerArguments) -TimeoutSeconds $TimeoutSeconds
        $lifecycle.Add([ordered]@{ operation = 'create'; exitCode = $create.ExitCode; timedOut = $create.TimedOut })
        if ($create.TimedOut -or $create.ExitCode -ne 0) {
            throw "Container creation failed: $($create.StandardError)"
        }
        $containerCreated = $true

        $run = Invoke-BoundedProcess -Executable $resolvedDockerExecutable -Arguments (@($DockerPrefixArguments) + @('start', '--attach', $containerName)) -TimeoutSeconds $TimeoutSeconds
        $lifecycle.Add([ordered]@{ operation = 'start'; exitCode = $run.ExitCode; timedOut = $run.TimedOut })
        if ($run.TimedOut) {
            $kill = Invoke-BoundedProcess -Executable $resolvedDockerExecutable -Arguments (@($DockerPrefixArguments) + @('kill', $containerName)) -TimeoutSeconds $TimeoutSeconds
            $lifecycle.Add([ordered]@{ operation = 'kill'; exitCode = $kill.ExitCode; timedOut = $kill.TimedOut })
        }
        $copy = Invoke-BoundedProcess -Executable $resolvedDockerExecutable -Arguments (@($DockerPrefixArguments) + @('cp', "$containerName`:/trace/strace.log", $tracePath)) -TimeoutSeconds $TimeoutSeconds
        $lifecycle.Add([ordered]@{ operation = 'copy'; exitCode = $copy.ExitCode; timedOut = $copy.TimedOut })
        if ($copy.TimedOut -or $copy.ExitCode -ne 0) {
            throw "Trace evidence copy failed: $($copy.StandardError)"
        }
        $attempts = @(Get-NetworkAttemptEvidence -TracePath $tracePath)
        $externalIntent = @($endpoints | Where-Object { $_.classification -in @('external-intent', 'unparseable') })
        $concerningAttempts = @($attempts | Where-Object { $_.classification -notin @('loopback', 'metadata') })

        $status = if ($sourceInventory.Count -eq 0) {
            'Inconclusive'
        }
        elseif ($run.TimedOut -or $run.ExitCode -ne 0) {
            'Failed'
        }
        elseif ($externalIntent.Count -gt 0 -or $concerningAttempts.Count -gt 0) {
            'ConcernObserved'
        }
        else {
            'Passed'
        }
        if ($NonAttesting -and $status -eq 'Passed') {
            $status = 'NonAttesting'
        }

        $report = [pscustomobject]@{
            status = $status
            executed = $true
            image = $Image
            imageIdentity = [ordered]@{ id = $imageInspection.Id; repoDigests = @($imageInspection.RepoDigests) }
            evidenceMode = if ($NonAttesting) { 'non-attesting' } else { 'attesting' }
            dockerExecutable = $resolvedDockerExecutable
            dockerArguments = @($DockerPrefixArguments) + $dockerArguments
            cargoLockSha256 = $lockHash
            inputManifest = $capture.Manifest
            provenance = $reportProvenance
            configuredContainment = [ordered]@{
                network = 'none'
                pull = 'never'
                cargo = 'offline'
                supervisorUser = '0:0'
                workloadUser = $resolvedContainerUser
                capabilitiesDropped = 'ALL'
                capabilityExceptions = @('SYS_PTRACE', 'SETUID', 'SETGID')
                noNewPrivileges = $true
                traceZone = '/trace root-only tmpfs'
                buildZone = '/build workload tmpfs'
            }
            container = [ordered]@{
                name = $containerName
                traceId = $traceId
                lifecycle = @($lifecycle)
            }
            test = [ordered]@{
                exitCode = $run.ExitCode
                timedOut = $run.TimedOut
                standardOutput = Limit-TraceText -Value $run.StandardOutput
                standardError = Limit-TraceText -Value $run.StandardError
            }
            literalEndpoints = $endpoints
            testPlacement = $testPlacement
            networkAttempts = $attempts
            emptyNonLoopbackListIsProofOfLoopbackOnly = $false
            nonClaims = @(
                'Configured containment supports a prevention claim only for attesting execution whose gates all passed.',
                'An empty network-attempt list is not proof that no network behavior was attempted.',
                'Textual endpoint extraction is not exhaustive proof of source behavior.',
                'Captured process output is untrusted generated data and is sanitized and truncated.'
            )
            cleanup = $cleanup
        }
    }
    finally {
        if ($containerCreated) {
            $remove = Invoke-BoundedProcess -Executable $resolvedDockerExecutable -Arguments (@($DockerPrefixArguments) + @('rm', '--force', $containerName)) -TimeoutSeconds $TimeoutSeconds
            $lifecycle.Add([ordered]@{ operation = 'remove'; exitCode = $remove.ExitCode; timedOut = $remove.TimedOut })
            $absence = Invoke-BoundedProcess -Executable $resolvedDockerExecutable -Arguments (@($DockerPrefixArguments) + @('container', 'inspect', $containerName)) -TimeoutSeconds $TimeoutSeconds
            $containerAbsent = -not $absence.TimedOut -and $absence.ExitCode -ne 0
            $lifecycle.Add([ordered]@{ operation = 'confirm-absent'; exitCode = $absence.ExitCode; timedOut = $absence.TimedOut; absent = $containerAbsent })
        }
        if ($containerCreated -and -not $containerAbsent) {
            $cleanup = 'Unconfirmed'
            $retainTemporary = $true
        }
        elseif (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
            $cleanup = if (Test-Path -LiteralPath $temporaryRoot) { 'Failed' } else { 'Complete' }
        }
    }
    if ($report) {
        $report.cleanup = $cleanup
        $report.container.lifecycle = @($lifecycle)
        if ($retainTemporary) {
            $report.status = 'Inconclusive'
            $report | Add-Member -NotePropertyName retainedEvidencePath -NotePropertyValue $temporaryRoot
        }
    }
    return $report
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-RustUnitTestNetworkTrace `
            -InputPath $InputPath `
            -ProvenancePath $ProvenancePath `
            -Image $Image `
            -OutputPath $OutputPath `
            -RepoRoot $RepoRoot `
            -DockerExecutable $DockerExecutable `
            -DockerPrefixArguments $DockerPrefixArguments `
            -NonAttesting:$NonAttesting `
            -ContainerUser $ContainerUser `
            -TimeoutSeconds $TimeoutSeconds `
            -Preview:$Preview
        if ($Preview) {
            $result | ConvertTo-Json -Depth 10
            exit 0
        }
        Write-TraceJson -Report $result -Path $OutputPath
        if ($result.status -eq 'Passed') { exit 0 }
        exit 1
    }
    catch {
        Write-Error -ErrorAction Continue "Rust unit-test network trace failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
