#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Verifies and reports on dependency pinning compliance for supply chain security.

.DESCRIPTION
    Cross-platform PowerShell script that analyzes GitHub Actions workflows, composite
    actions, package manifests, container definitions, and scripts to verify compliance
    with dependency pinning security practices. Identifies unpinned dependencies and
    provides remediation guidance.

.PARAMETER Path
    Root path to scan for dependency files. Defaults to current directory.

.PARAMETER Recursive
    Scan recursively through subdirectories. Default is true.

.PARAMETER Format
    Output format for compliance report. Options: json, sarif, csv, markdown, table.
    Default is 'json' for programmatic processing.

.PARAMETER OutputPath
    Path where compliance results should be saved. Defaults to 'dependency-pinning-report.json'
    in the current directory.

.PARAMETER FailOnUnpinned
    Exit with error code if pinning violations are found. Default is false for reporting mode.

.PARAMETER ExcludePaths
    Comma-separated list of paths to exclude from scanning (glob patterns supported).

.PARAMETER IncludeTypes
    Comma-separated list of dependency types to check. Options: github-actions, npm, pip,
    workflow-npm-commands, shell-downloads, setup-action-versions, python-tool-runs,
    container-images, install-hints. Default is all types.

.PARAMETER Threshold
    Minimum compliance score percentage required for passing grade (0-100).
    Script will exit with code 1 if compliance falls below threshold when -FailOnUnpinned is set.
    Default is 100%, so any unpinned dependency fails.

.PARAMETER Remediate
    Generate remediation suggestions with specific SHA pins for unpinned dependencies.

.EXAMPLE
    ./Test-DependencyPinning.ps1
    Scan current directory for dependency pinning compliance.

.EXAMPLE
    ./Test-DependencyPinning.ps1 -Path "/workspace" -Format "sarif" -FailOnUnpinned
    Scan workspace directory, output SARIF format, fail on violations.

.EXAMPLE
    ./Test-DependencyPinning.ps1 -IncludeTypes "github-actions,pip" -Remediate
    Check only GitHub Actions and pip dependencies with remediation suggestions.

.EXAMPLE
    ./Test-DependencyPinning.ps1 -Threshold 90 -FailOnUnpinned
    Enforce 90% compliance threshold and fail build if not met.

.EXAMPLE
    ./Test-DependencyPinning.ps1 -Threshold 100 -IncludeTypes "github-actions"
    Require 100% SHA pinning for GitHub Actions only.

.EXAMPLE
    ./Test-DependencyPinning.ps1 -Threshold 80
    Report compliance against 80% threshold but continue on violations.

.NOTES
    Requires:
    - PowerShell 7.0 or later for cross-platform compatibility
    - Internet connectivity for SHA resolution (with -Remediate)
    - GitHub API access for action SHA resolution (optional)

    Compatible with:
    - Windows PowerShell 5.1+ (limited cross-platform features)
    - PowerShell 7.x on Windows, Linux, macOS
    - GitHub Actions runners (ubuntu-latest, windows-latest, macos-latest)
    - Azure DevOps agents (Microsoft-hosted and self-hosted)

.LINK
    https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions
#>

# Import security classes from shared module
using module ./Modules/SecurityClasses.psm1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = ".",

    [Parameter(Mandatory = $false)]
    [ValidateSet('json', 'sarif', 'csv', 'markdown', 'table')]
    [string]$Format = 'json',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/dependency-pinning-results.json',

    [Parameter(Mandatory = $false)]
    [switch]$FailOnUnpinned,

    [Parameter(Mandatory = $false)]
    [string]$ExcludePaths = "",

    [Parameter(Mandatory = $false)]
    [string]$IncludeTypes = "github-actions,npm,pip,shell-downloads,workflow-npm-commands,setup-action-versions,python-tool-runs,container-images,install-hints",

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [int]$Threshold = 100,

    [Parameter(Mandatory = $false)]
    [switch]$Remediate
)

$ErrorActionPreference = 'Stop'

# Import CIHelpers for workflow command escaping
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/SecurityHelpers.psm1') -Force

$script:GitHubApiBase = Get-GitHubApiBase

# Define dependency patterns for different ecosystems
$DependencyPatterns = @{
    'github-actions' = @{
        FilePatterns    = @('**/.github/workflows/*.yml', '**/.github/workflows/*.yaml', '**/.github/actions/**/*.yml', '**/.github/actions/**/*.yaml')
        VersionPatterns = @(
            @{
                Pattern     = 'uses:\s*(?!docker://)([^@\s]+)@([^#\s]+)'
                Groups      = @{ Action = 1; Version = 2 }
                Description = 'GitHub Actions uses statements'
            }
            @{
                # A remote action or reusable workflow with no ref runs the default
                # branch; the empty second group never matches the SHA pin pattern.
                Pattern     = '^[ \t]*(?:-[ \t]+)?uses:[ \t]*[''"]?((?!\.{1,2}/|docker://|\$/)[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+?)()[''"]?[ \t]*(?:#[^\r\n]*)?\r?$'
                Groups      = @{ Action = 1; Version = 2 }
                Description = 'GitHub Actions uses statements without a ref'
            }
        )
        PinPattern      = '^[a-fA-F0-9]{40}$'
        RemediationUrl  = "$script:GitHubApiBase/repos/{0}/commits/{1}"
    }

    'npm'            = @{
        FilePatterns    = @('**/package.json')
        ExcludePatterns = @('node_modules')
        ValidationFunc  = 'Get-NpmDependencyViolations'
        RemediationUrl  = 'https://registry.npmjs.org/{0}/{1}'
    }

    'pip'              = @{
        FilePatterns    = @('**/requirements*.txt', '**/Pipfile', '**/pyproject.toml', '**/setup.py')
        ExcludePatterns = @('.venv', 'venv', '.tox', '.nox', '__pypackages__')
        # '#' starts a comment and ';' starts a PEP 508 environment marker. Both
        # carry '==' comparisons that are not package pins.
        IgnoreAfter     = @('#', ';')
        VersionPatterns = @(
            @{
                Pattern     = '([a-zA-Z0-9._-]+(?:\[[a-zA-Z0-9._,-]+\])?)\s*==\s*([^#\s,";]+)'
                Groups      = @{ Package = 1; Version = 2 }
                Description = 'Python pip requirements'
            }
        )
        PinPattern      = '^(?i:v?(?:\d+!)?\d+(?:\.\d+)*(?:(?:a|b|rc)\d+)?(?:\.post\d+)?(?:\.dev\d+)?(?:\+[a-z0-9]+(?:[._-][a-z0-9]+)*)?)$'
        RemediationUrl  = 'https://pypi.org/pypi/{0}/{1}/json'
    }

    'shell-downloads'  = @{
        FilePatterns    = @('**/*.sh', '**/.github/workflows/*.yml', '**/.github/workflows/*.yaml', '**/.github/actions/**/*.yml', '**/.github/actions/**/*.yaml')
        ExcludePatterns = @('fixtures', 'node_modules', "$([System.IO.Path]::DirectorySeparatorChar)tests$([System.IO.Path]::DirectorySeparatorChar)")
        ValidationFunc  = 'Test-ShellDownloadSecurity'
        Description     = 'Shell script and workflow downloads must include checksum verification'
    }

    'workflow-npm-commands' = @{
        FilePatterns   = @('**/.github/workflows/*.yml', '**/.github/workflows/*.yaml', '**/.github/actions/**/*.yml', '**/.github/actions/**/*.yaml')
        ValidationFunc = 'Get-WorkflowNpmCommandViolations'
        Description    = 'Workflow npm install/update commands should use npm ci'
    }

    'setup-action-versions' = @{
        FilePatterns   = @('**/.github/workflows/*.yml', '**/.github/workflows/*.yaml', '**/.github/actions/**/*.yml', '**/.github/actions/**/*.yaml')
        ValidationFunc = 'Get-SetupActionVersionViolations'
        Description    = 'Setup and installer actions must install an exact tool version'
    }

    'python-tool-runs' = @{
        FilePatterns    = @('**/.github/workflows/*.yml', '**/.github/workflows/*.yaml', '**/.github/actions/**/*.yml', '**/.github/actions/**/*.yaml', '**/*.sh', '**/*.ps1', '**/*.psm1')
        ExcludePatterns = @('fixtures', 'node_modules', "$([System.IO.Path]::DirectorySeparatorChar)tests$([System.IO.Path]::DirectorySeparatorChar)")
        ValidationFunc  = 'Get-PythonToolRunViolations'
        Description     = 'Python tools must run from a locked uv project, not uvx, uv tool, or pipx'
    }

    'container-images' = @{
        FilePatterns    = @('**/Dockerfile*', '**/*.Dockerfile', '**/Containerfile*', '**/compose*.yml', '**/compose*.yaml', '**/docker-compose*.yml', '**/docker-compose*.yaml', '**/.github/workflows/*.yml', '**/.github/workflows/*.yaml', '**/.github/actions/**/*.yml', '**/.github/actions/**/*.yaml')
        ExcludePatterns = @('fixtures', 'node_modules', "$([System.IO.Path]::DirectorySeparatorChar)tests$([System.IO.Path]::DirectorySeparatorChar)")
        ValidationFunc  = 'Get-ContainerImageViolations'
        Description     = 'Container images must be pinned by sha256 digest'
    }

    'install-hints' = @{
        FilePatterns    = @('**/*.ps1', '**/*.psm1', '**/*.sh', '**/*.py', '**/*.mjs', '**/*.cjs', '**/*.js', '**/.github/workflows/*.yml', '**/.github/workflows/*.yaml', '**/.github/actions/**/*.yml', '**/.github/actions/**/*.yaml')
        ExcludePatterns = @('fixtures', 'node_modules', "$([System.IO.Path]::DirectorySeparatorChar)tests$([System.IO.Path]::DirectorySeparatorChar)")
        ValidationFunc  = 'Get-InstallHintViolations'
        Description     = 'Messages and help must not recommend unverified or floating installs'
    }
}

# Version inputs for setup and installer actions. A file input pins through a
# version file (checked by Test-ToolVersionConsistency.ps1 for Node and Python);
# a version input must name one exact release.
$script:SetupActionVersionInputs = @{
    'actions/setup-node'             = @{ Version = 'node-version'; File = 'node-version-file' }
    'actions/setup-python'           = @{ Version = 'python-version'; File = 'python-version-file' }
    'actions/setup-go'               = @{ Version = 'go-version'; File = 'go-version-file' }
    'actions/setup-java'             = @{ Version = 'java-version'; File = 'java-version-file' }
    'actions/setup-dotnet'           = @{ Version = 'dotnet-version'; File = 'global-json-file' }
    'github/gh-aw-actions/setup-cli' = @{ Version = 'version'; File = $null }
    'sigstore/cosign-installer'      = @{ Version = 'cosign-release'; File = $null }
}
$script:ExactVersionPattern = '^v?\d+\.\d+\.\d+$'

# Install-hint patterns. The floating-tag pattern is assembled so this file does
# not match its own rule.
$script:InstallHintPatterns = @(
    @{ Pattern = '\b(?:curl|wget)\b[^|\r\n]*\|\s*(?:sudo\s+)?(?:ba|z|da)?sh\b'; Kind = 'a download piped to a shell' }
    @{ Pattern = '\b(?:irm|iwr|Invoke-RestMethod|Invoke-WebRequest)\b[^|\r\n]*\|\s*(?:iex|Invoke-Expression)\b'; Kind = 'a download piped to Invoke-Expression' }
    @{ Pattern = '@' + 'latest\b'; Kind = 'a floating latest tag' }
    @{ Pattern = '\bpip3?\s+install\s+(?!-)[A-Za-z0-9][A-Za-z0-9._-]*(?![A-Za-z0-9._-]*\s*(?:==|\[))'; Kind = 'an unversioned pip package' }
)

# DependencyViolation and ComplianceReport classes moved to ./Modules/SecurityClasses.psm1

#region Functions

function Test-NpmCommandLine {
    <#
    .SYNOPSIS
        Tests whether a line contains an unpinned npm command.
    .DESCRIPTION
        Matches npm install, npm i, npm update, and npm install-test commands.
        Does not match npm ci, npm run, npm test, npm audit, or npx.
    .PARAMETER Line
        The text line to test for npm commands.
    .OUTPUTS
        System.String or $null
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    if ($Line -match '\bnpm\s+(install-test|install|update)\b') {
        return $Matches[0]
    }
    if ($Line -match '\bnpm\s+i\b(?!nstall|nit)') {
        return $Matches[0]
    }

    return $null
}

function New-NpmCommandViolation {
    <#
    .SYNOPSIS
        Creates a DependencyViolation for an unpinned npm command.
    .DESCRIPTION
        Constructs a DependencyViolation object with standard fields for
        npm command violations detected in workflow run: steps.
    .PARAMETER FileInfo
        Hashtable with Path, Type, and RelativePath keys.
    .PARAMETER LineNumber
        1-based line number of the violation.
    .PARAMETER Line
        The source line containing the npm command.
    .PARAMETER Command
        The matched npm command string.
    .OUTPUTS
        DependencyViolation
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo,
        [Parameter(Mandatory)]
        [int]$LineNumber,
        [Parameter(Mandatory)]
        [string]$Line,
        [Parameter(Mandatory)]
        [string]$Command
    )

    $violation = [DependencyViolation]::new(
        $FileInfo.RelativePath,
        $LineNumber,
        'workflow-npm-commands',
        $Command,
        'Medium',
        "Unpinned npm command detected: '$Command'. Use 'npm ci' for deterministic installs from lockfile."
    )
    $violation.ViolationType = 'Unpinned'
    $violation.CurrentRef = $Line.Trim()
    $violation.Remediation = "Replace '$Command' with 'npm ci' for reproducible builds."
    return $violation
}

function Get-WorkflowNpmCommandViolations {
    <#
    .SYNOPSIS
        Detects unpinned npm install commands in GitHub Actions workflow run: steps.
    .DESCRIPTION
        Scans workflow YAML files for run: blocks and detects npm commands that
        modify the dependency tree (install, i, update, install-test). Commands
        that use the lockfile deterministically (ci) or do not install packages
        (run, test, audit) are not flagged.

        Uses indentation-aware parsing to confine detection to actual run: block
        content, reducing false positives from YAML comments or unrelated keys.
    .PARAMETER FileInfo
        Hashtable with Path, Type, and RelativePath keys identifying the file to scan.
    .OUTPUTS
        DependencyViolation[]
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo
    )

    $violations = @()
    $totalNpmCommands = 0
    $filePath = $FileInfo.Path

    if (-not (Test-Path -LiteralPath $filePath)) {
        return @{ TotalCount = 0; Violations = @() }
    }

    $lines = Get-Content -LiteralPath $filePath
    $inRunBlock = $false
    $runBlockIndent = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmed = $line.TrimStart()

        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) {
            continue
        }

        $currentIndent = $line.Length - $line.TrimStart().Length

        if ($trimmed -match '^run:\s*(.*)$') {
            $runContent = $Matches[1].Trim()
            $runBlockIndent = $currentIndent

            if ($runContent -and $runContent -notmatch '^[|>]') {
                $npmMatch = Test-NpmCommandLine -Line $runContent
                if ($npmMatch) {
                    $totalNpmCommands++
                    $violations += New-NpmCommandViolation -FileInfo $FileInfo -LineNumber ($i + 1) -Line $runContent -Command $npmMatch
                }
                $inRunBlock = $false
            } else {
                $inRunBlock = $true
            }
            continue
        }

        if ($inRunBlock) {
            if ($currentIndent -le $runBlockIndent) {
                $inRunBlock = $false
                if ($trimmed -match '^run:\s*(.*)$') {
                    $i--
                    continue
                }
            } else {
                if ($trimmed.StartsWith('#')) {
                    continue
                }
                $npmMatch = Test-NpmCommandLine -Line $trimmed
                if ($npmMatch) {
                    $totalNpmCommands++
                    $violations += New-NpmCommandViolation -FileInfo $FileInfo -LineNumber ($i + 1) -Line $trimmed -Command $npmMatch
                }
            }
        }
    }

    return @{ TotalCount = $totalNpmCommands; Violations = $violations }
}

function Test-ShellDownloadSecurity {
    <#
    .SYNOPSIS
        Scans shell scripts for curl/wget downloads lacking checksum verification.

    .DESCRIPTION
        Analyzes shell scripts and workflow run blocks to detect curl or wget
        downloads that are not followed by checksum verification
        (sha256sum/shasum) within the next 10 lines. A download is a curl or
        wget call with a literal http(s) URL, an output-file flag, or a pipe,
        so downloads from variable URLs are caught too. Comment lines are skipped.

    .PARAMETER FileInfo
        Hashtable with Path, Type, and RelativePath keys from Get-FilesToScan.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo
    )

    $FilePath = $FileInfo.Path

    if (-not (Test-Path $FilePath)) {
        return @{ TotalCount = 0; Violations = @() }
    }

    $lines = @(Get-Content $FilePath)
    $violations = @()
    $totalDownloads = 0

    $toolPattern = '(?<![\w./-])(curl|wget)\s'
    $downloadPattern = 'https?://|\s(-o|-O|-qO-?|--output|--remote-name|--output-document)(\s|=|$)|\|\s*(?:sudo\s+)?(?:(?:ba|z|da)?sh|tar)\b'
    $checksumPattern = 'sha256sum|shasum|Get-FileHash|openssl\s+dgst\s+-sha256|sha256sum\s+-c'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*#') { continue }
        if ($line -match $toolPattern -and $line -match $downloadPattern) {
            $totalDownloads++
            $hasChecksum = $false
            $searchEnd = [Math]::Min($i + 10, $lines.Count - 1)

            for ($j = $i; $j -le $searchEnd; $j++) {
                if ($lines[$j] -match $checksumPattern) {
                    $hasChecksum = $true
                    break
                }
            }

            if (-not $hasChecksum) {
                $violation = [DependencyViolation]::new()
                $violation.File = $FileInfo.RelativePath
                $violation.Line = $i + 1
                $violation.Type = $FileInfo.Type
                $violation.Name = $line.Trim()
                $violation.Severity = 'Medium'
                $violation.ViolationType = 'Unpinned'
                $violation.Description = 'Download without checksum verification'
                $violation.Metadata = @{ Pattern = $line.Trim() }
                $violations += $violation
            }
        }
    }

    return @{ TotalCount = $totalDownloads; Violations = $violations }
}

function New-PinningRuleViolation {
    <#
    .SYNOPSIS
        Creates a DependencyViolation for one of the expanded pinning rules.
    #>
    [CmdletBinding()]
    [OutputType([DependencyViolation])]
    param(
        [Parameter(Mandatory)][hashtable]$FileInfo,
        [Parameter(Mandatory)][int]$Line,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$Remediation,
        [Parameter()][string]$CurrentRef = ''
    )

    $violation = [DependencyViolation]::new()
    $violation.File = $FileInfo.RelativePath
    $violation.Line = $Line
    $violation.Type = $FileInfo.Type
    $violation.Name = $Name
    $violation.Severity = 'High'
    $violation.ViolationType = 'Unpinned'
    $violation.Description = $Description
    $violation.Remediation = $Remediation
    $violation.CurrentRef = $CurrentRef
    return $violation
}

function Get-SetupActionVersionViolations {
    <#
    .SYNOPSIS
        Flags setup and installer actions that do not install an exact version.

    .DESCRIPTION
        Checks every remote action whose path ends in setup-* or *-installer.
        The action must be listed in $script:SetupActionVersionInputs, and its
        step must name a version file or an exact X.Y.Z version. A missing,
        floating, or expression version is a violation, as is an unlisted setup
        action, so a new installer cannot slip through unreviewed.

    .PARAMETER FileInfo
        Hashtable with Path, Type, and RelativePath keys from Get-FilesToScan.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo
    )

    if (-not (Test-Path -LiteralPath $FileInfo.Path)) {
        return @{ TotalCount = 0; Violations = @() }
    }

    $content = (Get-Content -LiteralPath $FileInfo.Path -Raw) -replace "`r`n", "`n"
    if ($null -eq $content) { $content = '' }
    $steps = @(Get-WorkflowActionStep -Content $content -ActionPattern '^[^./][^@]*/(?:setup-[A-Za-z0-9-]+|[A-Za-z0-9-]+-installer)$')
    $violations = @()

    foreach ($step in $steps) {
        $spec = $script:SetupActionVersionInputs[$step.Action]
        if (-not $spec) {
            $violations += New-PinningRuleViolation -FileInfo $FileInfo -Line $step.Line -Name $step.Action `
                -Description "Setup action '$($step.Action)' has no registered version input, so its installed version cannot be verified" `
                -Remediation "Add '$($step.Action)' and its version input to `$SetupActionVersionInputs in Test-DependencyPinning.ps1, then pin an exact version"
            continue
        }

        $fileValue = if ($spec.File) { $step.Inputs[$spec.File] } else { $null }
        $versionValue = $step.Inputs[$spec.Version]
        if ($fileValue -and $fileValue -notmatch '\$\{\{') { continue }
        if ($versionValue -and $versionValue -match $script:ExactVersionPattern) { continue }

        $how = if ($spec.File) { "$($spec.File) or an exact $($spec.Version)" } else { "an exact $($spec.Version)" }
        if (-not $versionValue) {
            $description = "Setup action '$($step.Action)' installs no pinned version"
        }
        else {
            $description = "Setup action '$($step.Action)' installs floating version '$versionValue'"
        }
        $violations += New-PinningRuleViolation -FileInfo $FileInfo -Line $step.Line -Name $step.Action -CurrentRef "$versionValue" `
            -Description $description -Remediation "Set $how (X.Y.Z)"
    }

    return @{ TotalCount = $steps.Count; Violations = $violations }
}

function Get-PythonToolRunViolations {
    <#
    .SYNOPSIS
        Flags Python tools run through uvx, uv tool, or pipx.

    .DESCRIPTION
        These runners resolve the tool's transitive dependencies at run time
        with no lockfile or hashes, even when the top-level package is pinned.
        Tools must run from a locked uv project (uv run --locked or
        uv sync --locked). Version and help queries are not tool runs. Comment
        lines are skipped.

    .PARAMETER FileInfo
        Hashtable with Path, Type, and RelativePath keys from Get-FilesToScan.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo
    )

    if (-not (Test-Path -LiteralPath $FileInfo.Path)) {
        return @{ TotalCount = 0; Violations = @() }
    }

    $patterns = @(
        @{ Name = 'uvx'; Pattern = '(?<![\w./-])uvx\s+(?!--version\b|--help\b|-V\b|-h\b)[^\s|;&]' }
        @{ Name = 'uv tool'; Pattern = '(?<![\w./-])uv\s+tool\s+(?:install|run|upgrade)\b' }
        @{ Name = 'pipx'; Pattern = '(?<![\w./-])pipx\s+(?:run|install|inject|upgrade)\b' }
    )
    $lines = @(Get-Content -LiteralPath $FileInfo.Path)
    $violations = @()
    $total = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*#') { continue }
        foreach ($runner in $patterns) {
            if ($lines[$i] -notmatch $runner.Pattern) { continue }
            $total++
            $violations += New-PinningRuleViolation -FileInfo $FileInfo -Line ($i + 1) -Name $runner.Name -CurrentRef $lines[$i].Trim() `
                -Description "'$($runner.Name)' resolves the tool's transitive dependencies without a lockfile or hashes" `
                -Remediation 'Declare the tool in a uv project with a committed uv.lock and run it with uv run --locked or uv sync --locked'
            break
        }
    }

    return @{ TotalCount = $total; Violations = $violations }
}

function Get-ContainerImageViolations {
    <#
    .SYNOPSIS
        Flags container image references that are not pinned by sha256 digest.

    .DESCRIPTION
        Dockerfile and Containerfile FROM lines resolve ${VAR:-default} and ARG
        defaults and skip scratch and earlier build stages. YAML files are
        checked for image: keys, scalar container: values, docker:// actions,
        and registry-qualified images on docker pull, run, or create lines.
        References built from variables at run time cannot be resolved and are
        not counted.

    .PARAMETER FileInfo
        Hashtable with Path, Type, and RelativePath keys from Get-FilesToScan.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo
    )

    if (-not (Test-Path -LiteralPath $FileInfo.Path)) {
        return @{ TotalCount = 0; Violations = @() }
    }

    $lines = @(Get-Content -LiteralPath $FileInfo.Path)
    $fileName = [System.IO.Path]::GetFileName($FileInfo.Path)
    $isDockerfile = $fileName -match '^(Dockerfile|Containerfile)' -or $fileName -match '\.Dockerfile$'
    $digestPattern = '@sha256:[0-9a-f]{64}$'
    $refs = [System.Collections.Generic.List[object]]::new()

    if ($isDockerfile) {
        $argDefaults = @{}
        $stages = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*ARG\s+(\w+)=(\S+)') { $argDefaults[$Matches[1]] = $Matches[2].Trim('"', ''''); continue }
            $from = [regex]::Match($line, '^\s*FROM\s+(?:--platform=\S+\s+)?(?<ref>\S+)(?:\s+AS\s+(?<stage>\S+))?', 'IgnoreCase')
            if (-not $from.Success) { continue }
            $ref = $from.Groups['ref'].Value
            $expanded = [regex]::Replace($ref, '\$\{(\w+)(?::?-([^}]*))?\}|\$(\w+)', {
                    param($m)
                    $name = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[3].Value }
                    if ($m.Groups[2].Success -and $m.Groups[2].Value) { return $m.Groups[2].Value }
                    if ($argDefaults.ContainsKey($name)) { return $argDefaults[$name] }
                    return $m.Value
                })
            $isEarlierStage = $stages.Contains($expanded)
            if ($from.Groups['stage'].Success) { $null = $stages.Add($from.Groups['stage'].Value) }
            if ($expanded -eq 'scratch' -or $isEarlierStage) { continue }
            $refs.Add(@{ Line = $i + 1; Ref = $expanded })
        }
    }
    else {
        $registryRef = '(?<![\w./:-])(?<ref>(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?/[a-z0-9._/-]+(?::[A-Za-z0-9._-]+)?(?:@sha256:[0-9a-f]{64})?)'
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*#') { continue }
            $candidates = @()
            $image = [regex]::Match($line, '^\s*(?:-\s+)?image:\s*[''"]?(?<ref>[^''"\s#]+)')
            if ($image.Success) { $candidates += $image.Groups['ref'].Value }
            $container = [regex]::Match($line, '^\s*container:\s*[''"]?(?<ref>[^''"\s#{][^''"\s#]*)')
            if ($container.Success) { $candidates += $container.Groups['ref'].Value }
            $docker = [regex]::Match($line, 'uses:\s*[''"]?docker://(?<ref>[^''"\s#]+)')
            if ($docker.Success) { $candidates += $docker.Groups['ref'].Value }
            if ($line -match '\bdocker\s+(?:pull|run|create)\b') {
                $candidates += @([regex]::Matches($line, $registryRef) | ForEach-Object { $_.Groups['ref'].Value })
            }
            foreach ($candidate in $candidates) {
                $expanded = [regex]::Replace($candidate, '\$\{(\w+):?-([^}]*)\}', '$2')
                if ($expanded -match '\$') { continue }
                $refs.Add(@{ Line = $i + 1; Ref = $expanded })
            }
        }
    }

    $violations = @()
    foreach ($ref in $refs) {
        if ($ref.Ref -match $digestPattern) { continue }
        $violations += New-PinningRuleViolation -FileInfo $FileInfo -Line $ref.Line -Name $ref.Ref -CurrentRef $ref.Ref `
            -Description "Container image '$($ref.Ref)' is not pinned by sha256 digest" `
            -Remediation 'Pin the image as name:tag@sha256:<digest> so the pulled content cannot change'
    }

    return @{ TotalCount = $refs.Count; Violations = $violations }
}

function Get-InstallHintViolations {
    <#
    .SYNOPSIS
        Flags messages and help text that recommend unverified or floating installs.

    .DESCRIPTION
        Error messages, help text, and comments are copied into terminals. A
        hint that pipes a download into a shell or Invoke-Expression, installs a
        floating latest tag, or names a pip package without a version teaches an
        unverified install. Every line is checked, including comments.

    .PARAMETER FileInfo
        Hashtable with Path, Type, and RelativePath keys from Get-FilesToScan.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo
    )

    if (-not (Test-Path -LiteralPath $FileInfo.Path)) {
        return @{ TotalCount = 0; Violations = @() }
    }

    $lines = @(Get-Content -LiteralPath $FileInfo.Path)
    $violations = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($hint in $script:InstallHintPatterns) {
            $match = [regex]::Match($lines[$i], $hint.Pattern)
            if (-not $match.Success) { continue }
            $violations += New-PinningRuleViolation -FileInfo $FileInfo -Line ($i + 1) -Name $hint.Kind -CurrentRef $lines[$i].Trim() `
                -Description "Install hint recommends $($hint.Kind): '$($match.Value.Trim())'" `
                -Remediation 'Point to a pinned, checksum-verified install: a package manager that verifies downloads, a release archive checked against its published SHA-256, or a locked project (uv sync --locked, npm ci)'
            break
        }
    }

    return @{ TotalCount = $violations.Count; Violations = $violations }
}

function Get-NpmDependencyViolations {
    <#
    .SYNOPSIS
        Analyzes package.json files for unpinned npm dependencies.
    .DESCRIPTION
        Parses package.json as JSON and checks dependency sections
        (dependencies, devDependencies, peerDependencies, optionalDependencies)
        for exact version pinning. Versions must be exact semver (e.g. 1.2.3)
        without range operators like ^, ~, *, >=, ||, or URL/git references.
    .PARAMETER FileInfo
        Hashtable with Path, Type, and RelativePath keys from Get-FilesToScan.
    .OUTPUTS
        Array of PSCustomObjects representing dependency violations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$FileInfo
    )

    $filePath = $FileInfo.Path
    $relativePath = $FileInfo.RelativePath
    $type = $FileInfo.Type
    $violations = @()
    $totalCount = 0

    if (-not (Test-Path -Path $filePath -PathType Leaf)) {
        return @{ TotalCount = 0; Violations = @() }
    }

    try {
        $content = Get-Content -Path $filePath -Raw -ErrorAction Stop
        $packageJson = $content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to parse $relativePath as JSON: $_"
        return @{ TotalCount = 0; Violations = @() }
    }

    # Build a line-number lookup from raw file content
    $lines = Get-Content -Path $filePath -ErrorAction SilentlyContinue

    $dependencySections = @('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies')

    foreach ($section in $dependencySections) {
        $deps = $packageJson.$section
        if ($null -eq $deps) {
            continue
        }

        foreach ($prop in $deps.PSObject.Properties) {
            $packageName = $prop.Name
            $version = $prop.Value

            if ([string]::IsNullOrWhiteSpace($version)) {
                continue
            }

            $totalCount++
            $isPinned = Test-NpmExactVersion -Version $version

            if (-not $isPinned) {
                # Find the line number by searching for the package name in the file
                $lineNumber = 1
                if ($null -ne $lines) {
                    $escapedName = [regex]::Escape($packageName)
                    for ($i = 0; $i -lt $lines.Count; $i++) {
                        if ($lines[$i] -match """$escapedName""\s*:") {
                            $lineNumber = $i + 1
                            break
                        }
                    }
                }

                $violation = [DependencyViolation]::new()
                $violation.File = $relativePath
                $violation.Line = $lineNumber
                $violation.Type = $type
                $violation.Name = $packageName
                $violation.Version = $version
                $violation.Severity = 'Medium'
                $violation.ViolationType = 'Unpinned'
                $violation.Description = "Unpinned npm dependency in $section"
                $violation.Metadata = @{ Section = $section }
                $violations += $violation
            }
        }
    }

    return @{ TotalCount = $totalCount; Violations = $violations }
}

function Test-NpmExactVersion {
    <#
    .SYNOPSIS
        Tests whether an npm version string is an exact pinned version.
    .DESCRIPTION
        Returns $true for exact semver versions (e.g. 1.2.3, 1.0.0-beta.1).
        Returns $true for local-path protocol references (file:, link:) because
        they resolve to in-repo paths rather than registry downloads and cannot
        be version- or SHA-pinned.
        Returns $false for ranges, wildcards, URLs, tags, and git references.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version
    )

    # Local-path protocol references resolve to in-repo paths, not registry
    # downloads, so they pose no supply-chain pinning risk.
    if ($Version -match '^(file|link):') {
        return $true
    }

    # Reject range operators, wildcards, URLs, git refs, and tags like "latest"
    if ($Version -match '^[~^>=<*|]' -or
        $Version -match '://' -or
        $Version -match '\.git\b' -or
        $Version -match '\s*\|\|' -or
        $Version -match '^\w+$' -and $Version -notmatch '^\d') {
        return $false
    }

    # Accept exact semver: major.minor.patch with optional prerelease/build metadata
    return $Version -match '^\d+\.\d+\.\d+(-[a-zA-Z0-9._-]+)?(\+[a-zA-Z0-9._-]+)?$'
}

function Get-TrackedFilePathSet {
    <#
    .SYNOPSIS
    Returns the set of git-tracked file paths under a scan root.

    .DESCRIPTION
    CI scans a clean checkout, so an ignored or untracked working-tree file is
    content the pipeline never sees. Counting it locally produces compliance
    failures that cannot be reproduced in CI. Returns $null when the scan root
    is not a usable git working tree, which the caller treats as a reason to
    scan every file rather than to scan none.

    .PARAMETER ScanPath
    Root directory being scanned.

    .OUTPUTS
    [System.Collections.Generic.HashSet[string]] Full paths, or $null.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.HashSet[string]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScanPath
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    if (-not (Test-Path -LiteralPath $ScanPath -PathType Container)) { return $null }

    # Paths come back relative to ScanPath, so a subdirectory scan stays correct.
    $tracked = & git -C $ScanPath ls-files --cached 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }

    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($relative in $tracked) {
        if ([string]::IsNullOrWhiteSpace($relative)) { continue }
        $full = Join-Path $ScanPath ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        $null = $set.Add([System.IO.Path]::GetFullPath($full))
    }
    return $set
}

function Get-FilesToScan {
    <#
    .SYNOPSIS
    Discovers files to scan based on dependency type patterns.
    #>
    [CmdletBinding()]
    param(
        [string]$ScanPath,
        [string[]]$Types,
        [string[]]$ExcludePatterns
    )

    $allFiles = @()
    $trackedPaths = Get-TrackedFilePathSet -ScanPath $ScanPath
    if ($null -eq $trackedPaths) {
        Write-SecurityLog -CIAnnotation "Scan root is not a git working tree; scanning all matching files." -Level Info
    }

    foreach ($type in $Types) {
        if ($DependencyPatterns.ContainsKey($type)) {
            $patterns = $DependencyPatterns[$type].FilePatterns

            foreach ($pattern in $patterns) {
                try {
                    # Decompose glob into a directory prefix and a leaf filename filter.
                    # Get-ChildItem -Path does not expand ** globs on all platforms,
                    # so we strip the ** segments and use -Recurse with -Filter instead.
                    $segments = $pattern -split '[/\\]'
                    $leafFilter = $segments[-1]
                    $dirSegments = $segments[0..($segments.Length - 2)] | Where-Object { $_ -ne '**' }

                    if ($dirSegments.Count -gt 0) {
                        $basePath = Join-Path $ScanPath ($dirSegments -join [System.IO.Path]::DirectorySeparatorChar)
                    }
                    else {
                        $basePath = $ScanPath
                    }

                    if (-not (Test-Path -Path $basePath -PathType Container)) {
                        continue
                    }

                    $files = Get-ChildItem -Path $basePath -Filter $leafFilter -Recurse -File -ErrorAction SilentlyContinue

                    if ($null -ne $trackedPaths) {
                        $files = $files | Where-Object { $trackedPaths.Contains([System.IO.Path]::GetFullPath($_.FullName)) }
                    }

                    # Merge type-specific exclude patterns with caller-provided patterns
                    $mergedExcludes = @()
                    if ($ExcludePatterns) {
                        $mergedExcludes += @($ExcludePatterns)
                    }
                    if ($DependencyPatterns[$type].ContainsKey('ExcludePatterns')) {
                        $mergedExcludes += $DependencyPatterns[$type].ExcludePatterns
                    }

                    if ($mergedExcludes) {
                        foreach ($exclude in $mergedExcludes) {
                            $files = $files | Where-Object { $_.FullName -notlike "*$exclude*" }
                        }
                    }

                    $allFiles += $files | ForEach-Object {
                        @{
                            Path         = $_.FullName
                            Type         = $type
                            RelativePath = [System.IO.Path]::GetRelativePath($ScanPath, $_.FullName)
                        }
                    }
                }
                catch {
                    Write-SecurityLog -CIAnnotation "Error scanning for $type files with pattern $pattern`: $($_.Exception.Message)" -Level Warning
                }
            }
        }
    }

    return $allFiles | Sort-Object Path, Type -Unique
}

function Test-DependencyPinned {
    <#
    .SYNOPSIS
    Tests whether a dependency reference matches its ecosystem pin pattern.
    #>
    [CmdletBinding()]
    param(
        [string]$Version,
        [string]$Type
    )

    if ($DependencyPatterns.ContainsKey($Type) -and $DependencyPatterns[$Type].PinPattern) {
        $pinPattern = $DependencyPatterns[$Type].PinPattern
        return $Version -match $pinPattern
    }

    return $false
}

function Get-MatchableContent {
    <#
    .SYNOPSIS
    Blanks trailing line segments a dependency matcher must not read.

    .DESCRIPTION
    A pip requirement carries its environment marker after ';', and both
    requirements files and pyproject.toml use '#' for comments. Each segment can
    hold an '==' comparison that is not a package pin: `sys_platform == 'linux'`
    names a marker variable, not a package. Blanking with spaces rather than
    removing keeps every match index, and therefore every reported line number,
    identical to the original file.

    .PARAMETER Content
    Raw file content.

    .PARAMETER IgnoreAfter
    Characters whose first occurrence on a line begins an ignorable segment.

    .OUTPUTS
    [string] Content with ignorable segments replaced by spaces.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [char[]]$IgnoreAfter
    )

    if ([string]::IsNullOrEmpty($Content)) { return $Content }

    $builder = [System.Text.StringBuilder]::new($Content.Length)
    $ignoring = $false
    foreach ($character in $Content.ToCharArray()) {
        if ($character -eq [char]10 -or $character -eq [char]13) {
            $ignoring = $false
            $null = $builder.Append($character)
            continue
        }
        if (-not $ignoring -and $IgnoreAfter -contains $character) {
            $ignoring = $true
        }
        $null = $builder.Append($(if ($ignoring) { ' ' } else { $character }))
    }

    return $builder.ToString()
}

function Get-DependencyViolation {
    <#
    .SYNOPSIS
    Scans a file for dependency pinning violations.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$FileInfo
    )

    $violations = @()
    $filePath = $FileInfo.Path
    $fileType = $FileInfo.Type

    if (!(Test-Path $filePath)) {
        return @{ TotalCount = 0; Violations = @() }
    }

    # Check if this type uses a validation function instead of regex patterns
    if ($null -ne $DependencyPatterns[$fileType].ValidationFunc) {
        $funcName = $DependencyPatterns[$fileType].ValidationFunc
        $scanResult = & $funcName -FileInfo $FileInfo

        if ($null -eq $scanResult) {
            return @{ TotalCount = 0; Violations = @() }
        }

        foreach ($v in @($scanResult.Violations)) {
            if ($null -eq $v) {
                continue
            }

            if (-not ($v -is [DependencyViolation])) {
                $actualType = $v.GetType().FullName
                throw "Validation function '$funcName' must return [DependencyViolation] objects, got '$actualType'."
            }

            if (-not $v.File) {
                $v.File = $FileInfo.RelativePath
            }

            if ($v.Line -lt 1) {
                $v.Line = 1
            }

            if (-not $v.Type) {
                $v.Type = $fileType
            }
        }

        return $scanResult
    }

    try {
        $content = Get-Content -Path $filePath -Raw
        $lines = Get-Content -Path $filePath

        $ignoreAfter = $DependencyPatterns[$fileType].IgnoreAfter
        if ($ignoreAfter) {
            $content = Get-MatchableContent -Content $content -IgnoreAfter $ignoreAfter
        }

        $patterns = $DependencyPatterns[$fileType].VersionPatterns
        $totalCount = 0

        foreach ($patternInfo in $patterns) {
            $pattern = $patternInfo.Pattern
            $description = $patternInfo.Description

            $regexMatches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
            $totalCount += @($regexMatches).Count

            foreach ($match in $regexMatches) {
                # Find line number
                $lineNumber = 1
                $position = $match.Index
                for ($i = 0; $i -lt $position; $i++) {
                    if ($content[$i] -eq "`n") {
                        $lineNumber++
                    }
                }

                # Extract dependency information
                $dependencyName = $match.Groups[1].Value
                $version = $match.Groups[2].Value

                # Check if properly pinned
                if (!(Test-DependencyPinned -Version $version -Type $fileType)) {
                    $violation = [DependencyViolation]::new()
                    $violation.File = $FileInfo.RelativePath
                    $violation.Line = $lineNumber
                    $violation.Type = $fileType
                    $violation.Name = $dependencyName
                    $violation.Version = $version
                    $violation.CurrentRef = $match.Value
                    $violation.Description = "Unpinned dependency: $description"
                    $violation.Severity = if ($fileType -eq 'github-actions') { 'High' } else { 'Medium' }
                    $violation.ViolationType = 'Unpinned'
                    $violation.Metadata['PatternDescription'] = $description
                    $violation.Metadata['LineContent'] = $lines[$lineNumber - 1]

                    $violations += $violation
                }
            }
        }
    }
    catch {
        Write-SecurityLog -CIAnnotation "Error scanning file $filePath`: $($_.Exception.Message)" -Level Warning
    }

    return @{ TotalCount = $totalCount; Violations = $violations }
}

function Get-RemediationSuggestion {
    <#
    .SYNOPSIS
    Generates remediation suggestions for unpinned dependencies.
    #>
    [CmdletBinding()]
    param(
        [DependencyViolation]$Violation,

        [switch]$Remediate
    )

    $type = $Violation.Type
    $name = $Violation.Name
    $version = $Violation.Version

    if (!$Remediate) {
        return "Enable -Remediate flag for specific SHA suggestions"
    }

    try {
        switch ($type) {
            'github-actions' {
                # For GitHub Actions, resolve tag to commit SHA
                $apiUrl = "$script:GitHubApiBase/repos/$name/commits/$version"
                $headers = @{}

                if ($env:GITHUB_TOKEN) {
                    $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
                }

                $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 30
                $sha = $response.sha

                if ($sha) {
                    return "Pin to SHA: uses: $name@$sha # $version"
                }
            }

            default {
                return "Research and pin to specific commit SHA or content hash for $type dependencies"
            }
        }
    }
    catch {
        Write-SecurityLog -CIAnnotation "Could not generate automatic remediation for $($Violation.Name): $($_.Exception.Message)" -Level Warning
    }

    return "Manually research and pin to immutable reference"
}

function Get-ComplianceReportData {
    <#
    .SYNOPSIS
    Generates a comprehensive compliance report.
    #>
    [CmdletBinding()]
    param(
        [DependencyViolation[]]$Violations,
        [hashtable[]]$ScannedFiles,
        [string]$ScanPath,
        [Parameter(Mandatory)]
        [int]$TotalDependencies,
        [switch]$Remediate
    )

    $report = [ComplianceReport]::new()
    $report.ScanPath = $ScanPath
    $report.ScannedFiles = $ScannedFiles.Count
    $report.Violations = $Violations

    # Calculate metrics using true dependency counts from scanners
    $report.TotalDependencies = $TotalDependencies
    $report.UnpinnedDependencies = @($Violations).Count
    $report.PinnedDependencies = $TotalDependencies - $report.UnpinnedDependencies
    $report.CalculateScore()

    # Generate summary by type
    $report.Summary = @{}
    foreach ($type in @($Violations | Group-Object Type)) {
        $report.Summary[$type.Name] = @{
            Total  = $type.Count
            High   = @($type.Group | Where-Object { $_.Severity -eq 'High' }).Count
            Medium = @($type.Group | Where-Object { $_.Severity -eq 'Medium' }).Count
            Low    = @($type.Group | Where-Object { $_.Severity -eq 'Low' }).Count
        }
    }

    # Add metadata
    $report.Metadata = @{
        PowerShellVersion  = $PSVersionTable.PSVersion.ToString()
        Platform           = $PSVersionTable.Platform
        ScanTimestamp      = $report.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
        IncludedTypes      = $IncludeTypes
        ExcludedPaths      = $ExcludePaths
        RemediationEnabled = $Remediate.IsPresent
        ComplianceThreshold = $Threshold
    }

    return $report
}

function Export-ComplianceReport {
    <#
    .SYNOPSIS
    Exports compliance report in specified format.
    #>
    [CmdletBinding()]
    param(
        # Use duck typing to avoid class type collision during code coverage instrumentation
        $Report,
        [string]$Format,
        [string]$OutputPath
    )

    # Validate required properties on duck-typed $Report parameter (ComplianceReport schema)
    $requiredProperties = @('ComplianceScore', 'Violations', 'TotalDependencies', 'UnpinnedDependencies', 'Metadata')
    foreach ($prop in $requiredProperties) {
        if ($null -eq $Report.PSObject.Properties[$prop]) {
            throw "Report object missing required property: $prop"
        }
    }

    # Ensure parent directory exists
    $parentDir = Split-Path -Path $OutputPath -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    switch ($Format.ToLower()) {
        'json' {
            $Report | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        }

        'sarif' {
            $sarif = @{
                version    = "2.1.0"
                "`$schema" = "https://json.schemastore.org/sarif-2.1.0.json"
                runs       = @(@{
                        tool    = @{
                            driver = @{
                                name           = "dependency-pinning-analyzer"
                                version        = "1.0.0"
                                informationUri = "https://github.com/microsoft/hve-core"
                            }
                        }
                        results = @($Report.Violations | ForEach-Object {
                                @{
                                    ruleId     = "dependency-not-pinned"
                                    level      = switch ($_.Severity) { 'High' { 'error' } 'Medium' { 'warning' } default { 'note' } }
                                    message    = @{ text = $_.Description }
                                    locations  = @(@{
                                            physicalLocation = @{
                                                artifactLocation = @{ uri = $_.File }
                                                region           = @{ startLine = $_.Line }
                                            }
                                        })
                                    properties = @{
                                        dependencyName = $_.Name
                                        currentVersion = $_.Version
                                        remediation    = $_.Remediation
                                    }
                                }
                            })
                    })
            }
            $sarif | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        }

        'csv' {
            $Report.Violations | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        }

        'markdown' {
            $markdown = @"
# Dependency Pinning Compliance Report

**Scan Date:** $($Report.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))
**Scan Path:** $($Report.ScanPath)
**Compliance Score:** $($Report.ComplianceScore)%

## Summary

| Metric | Count |
|--------|--------|
| Total Files Scanned | $($Report.ScannedFiles) |
| Total Dependencies | $($Report.TotalDependencies) |
| Pinned Dependencies | $($Report.PinnedDependencies) |
| Unpinned Dependencies | $($Report.UnpinnedDependencies) |

## Violations by Type

"@
            foreach ($type in $Report.Summary.Keys) {
                $summary = $Report.Summary[$type]
                $markdown += @"

### $type
- **Total:** $($summary.Total)
- **High Severity:** $($summary.High)
- **Medium Severity:** $($summary.Medium)
- **Low Severity:** $($summary.Low)

"@
            }

            if ($Report.Violations.Count -gt 0) {
                $markdown += @"

## Detailed Violations

| File | Line | Type | Dependency | Current Version | Severity | Remediation |
|------|------|------|------------|----------------|----------|-------------|
"@
                foreach ($violation in $Report.Violations) {
                    $markdown += "|$($violation.File)|$($violation.Line)|$($violation.Type)|$($violation.Name)|$($violation.Version)|$($violation.Severity)|$($violation.Remediation)|`n"
                }
            }

            $markdown | Out-File -FilePath $OutputPath -Encoding UTF8
        }

        'table' {
            # Display formatted table to console and save simple text format
            if ($Report.Violations.Count -gt 0) {
                $Report.Violations | Format-Table -Property File, Line, Type, Name, Version, Severity -AutoSize | Out-File -FilePath $OutputPath -Encoding UTF8 -Width 200
            }
            else {
                "No dependency pinning violations found." | Out-File -FilePath $OutputPath -Encoding UTF8
            }
        }
    }

    Write-SecurityLog -CIAnnotation "Compliance report exported to: $OutputPath" -Level Success
}

function Export-CICDArtifact {
    <#
    .SYNOPSIS
    Exports compliance report as CI/CD artifacts for both GitHub Actions and Azure DevOps.
    #>
    [CmdletBinding()]
    param(
        [ComplianceReport]$Report,
        [string]$ReportPath
    )

    Write-SecurityLog -CIAnnotation "Preparing compliance artifacts for CI/CD systems..." -Level Info

    $platform = Get-CIPlatform
    Write-SecurityLog -CIAnnotation "Detected $platform environment - setting up artifacts" -Level Info

    # Set CI outputs (works for both GitHub Actions and Azure DevOps)
    Set-CIOutput -Name 'dependency-report' -Value $ReportPath -IsOutput
    Set-CIOutput -Name 'compliance-score' -Value $Report.ComplianceScore -IsOutput
    Set-CIOutput -Name 'unpinned-count' -Value $Report.UnpinnedDependencies -IsOutput

    # Create summary content
    $summaryContent = @"
# 📌 Dependency Pinning Analysis

**Compliance Score:** $($Report.ComplianceScore)%
**Unpinned Dependencies:** $($Report.UnpinnedDependencies)
**Total Dependencies Scanned:** $($Report.TotalDependencies)

$(if ($Report.UnpinnedDependencies -gt 0) { "⚠️ **Action Required:** $($Report.UnpinnedDependencies) dependencies are not properly pinned to immutable references." } else { "✅ **All Clear:** All dependencies are properly pinned!" })
"@

    # Write step summary
    Write-CIStepSummary -Content $summaryContent

    # Publish artifact
    Publish-CIArtifact -Path $ReportPath -Name 'dependency-pinning-report' -ContainerFolder 'dependency-pinning'

    # Set up local artifact directory for GitHub Actions upload-artifact action
    if ($platform -eq 'github') {
        $artifactDir = Join-Path $PWD "dependency-pinning-artifacts"
        New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
        Copy-Item -Path $ReportPath -Destination $artifactDir -Force
    }

    Write-SecurityLog -CIAnnotation "Compliance artifacts prepared for CI/CD consumption" -Level Success
}

function Invoke-DependencyPinningAnalysis {
    <#
    .SYNOPSIS
        Orchestrates dependency pinning compliance analysis.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$Path = ".",

        [Parameter()]
        [string]$IncludeTypes = "github-actions,npm,pip,shell-downloads,workflow-npm-commands,setup-action-versions,python-tool-runs,container-images,install-hints",

        [Parameter()]
        [string]$ExcludePaths = "",

        [Parameter()]
        [string]$Format = 'json',

        [Parameter()]
        [string]$OutputPath = 'logs/dependency-pinning-results.json',

        [Parameter()]
        [switch]$FailOnUnpinned,

        [Parameter()]
        [int]$Threshold = 100,

        [Parameter()]
        [switch]$Remediate
    )

    Write-SecurityLog -CIAnnotation "Starting dependency pinning compliance analysis..." -Level Info
    Write-SecurityLog -CIAnnotation "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Info
    Write-SecurityLog -CIAnnotation "Platform: $($PSVersionTable.Platform)" -Level Info

    # Parse include types and exclude paths
    $typesToCheck = $IncludeTypes.Split(',') | ForEach-Object { $_.Trim() }
    $excludePatterns = if ($ExcludePaths) { $ExcludePaths.Split(',') | ForEach-Object { $_.Trim() } } else { @() }

    Write-SecurityLog -CIAnnotation "Scanning path: $Path" -Level Info
    Write-SecurityLog -CIAnnotation "Include types: $($typesToCheck -join ', ')" -Level Info
    if ($excludePatterns) { Write-SecurityLog -CIAnnotation "Exclude patterns: $($excludePatterns -join ', ')" -Level Info }

    # Discover files to scan
    $filesToScan = @(Get-FilesToScan -ScanPath $Path -Types $typesToCheck -ExcludePatterns $excludePatterns)
    Write-SecurityLog -CIAnnotation "Found $(@($filesToScan).Count) files to scan" -Level Info

    # Scan for violations
    $allViolations = @()
    $totalDependencyCount = 0
    foreach ($fileInfo in $filesToScan) {
        Write-SecurityLog -CIAnnotation "Scanning: $($fileInfo.RelativePath)" -Level Info
        $scanResult = Get-DependencyViolation -FileInfo $fileInfo
        $totalDependencyCount += $scanResult.TotalCount
        $violations = @($scanResult.Violations)

        # Add remediation suggestions
        foreach ($violation in $violations) {
            $violation.Remediation = Get-RemediationSuggestion -Violation $violation -Remediate:$Remediate
        }

        $allViolations += $violations
    }

    Write-SecurityLog -CIAnnotation "Found $(@($allViolations).Count) dependency pinning violations" -Level Info

    # Emit per-violation CI annotations and console output
    if ($allViolations.Count -gt 0) {
        Write-Host "`n❌ Found $($allViolations.Count) unpinned dependencies:" -ForegroundColor Red
        $groupedByFile = $allViolations | Group-Object -Property File
        foreach ($fileGroup in $groupedByFile) {
            Write-Host "`n📄 $($fileGroup.Name)" -ForegroundColor Cyan
            foreach ($dep in $fileGroup.Group) {
                $annotationLevel = switch ($dep.Severity) {
                    'High'   { 'Error' }
                    'Medium' { 'Warning' }
                    default  { 'Notice' }
                }
                $icon = switch ($dep.Severity) {
                    'High'   { '❌' }
                    'Medium' { '⚠️' }
                    default  { 'ℹ️' }
                }
                $color = switch ($dep.Severity) {
                    'High'   { 'Red' }
                    'Medium' { 'Yellow' }
                    default  { 'Cyan' }
                }
                Write-Host "  $icon [$($dep.Severity)] $($dep.Name)@$($dep.Version): $($dep.Description) (Line $($dep.Line))" -ForegroundColor $color
                Write-CIAnnotation `
                    -Message "[$($dep.ViolationType)] $($dep.Name): $($dep.Description)" `
                    -Level $annotationLevel `
                    -File $dep.File `
                    -Line $dep.Line
            }
        }
    }
    else {
        Write-Host "`n✅ All dependencies are properly pinned." -ForegroundColor Green
    }

    # Generate compliance report
    $report = Get-ComplianceReportData -Violations $allViolations -ScannedFiles $filesToScan -ScanPath $Path -TotalDependencies $totalDependencyCount -Remediate:$Remediate

    # Export report
    Export-ComplianceReport -Report $report -Format $Format -OutputPath $OutputPath

    # Export CI/CD artifacts
    Export-CICDArtifact -Report $report -ReportPath $OutputPath

    # Display summary
    Write-SecurityLog -CIAnnotation "Compliance Analysis Complete!" -Level Success
    Write-SecurityLog -CIAnnotation "Compliance Score: $($report.ComplianceScore)%" -Level Info
    Write-SecurityLog -CIAnnotation "Total Dependencies: $($report.TotalDependencies)" -Level Info
    Write-SecurityLog -CIAnnotation "Unpinned Dependencies: $($report.UnpinnedDependencies)" -Level Info

    if ($report.UnpinnedDependencies -gt 0) {
        Write-SecurityLog -CIAnnotation "$($report.UnpinnedDependencies) dependencies require pinning for security compliance" -Level Warning

        # Check threshold compliance
        if ($report.ComplianceScore -lt $Threshold) {
            Write-SecurityLog -CIAnnotation "Compliance score $($report.ComplianceScore)% is below threshold $Threshold%" -Level Error

            if ($FailOnUnpinned) {
                Write-SecurityLog -CIAnnotation "Failing build due to compliance threshold violation (-FailOnUnpinned enabled)" -Level Error
                throw "Compliance score $($report.ComplianceScore)% is below threshold $Threshold% (-FailOnUnpinned enabled)"
            }
            else {
                Write-SecurityLog -CIAnnotation "Threshold violation detected but continuing (soft-fail mode)" -Level Warning
            }
        }
        else {
            Write-SecurityLog -CIAnnotation "Compliance score $($report.ComplianceScore)% meets threshold $Threshold%" -Level Info
        }
    }
    else {
        Write-SecurityLog -CIAnnotation "All dependencies are properly pinned! ✅ (100% compliance, exceeds $Threshold% threshold)" -Level Success
    }
}

#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-DependencyPinningAnalysis `
            -Path $Path `
            -IncludeTypes $IncludeTypes `
            -ExcludePaths $ExcludePaths `
            -Format $Format `
            -OutputPath $OutputPath `
            -FailOnUnpinned:$FailOnUnpinned `
            -Threshold $Threshold `
            -Remediate:$Remediate
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Test-DependencyPinning failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
