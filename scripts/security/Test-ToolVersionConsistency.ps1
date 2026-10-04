#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Test-ToolVersionConsistency.ps1
#
# Purpose: Fail when a hard-coded tool version or checksum disagrees with
#          scripts/security/tool-checksums.json, the single tool-version source,
#          or a runtime setup disagrees with .node-version or .python-version.
# Author: HVE Core Team

#Requires -Version 7.4

<#
.SYNOPSIS
    Checks that every hard-coded tool version and checksum matches the tool manifest.

.DESCRIPTION
    Validates scripts/security/tool-checksums.json, then scans workflows,
    composite actions, and devcontainer scripts:

      tool-version/manifest-invalid      the manifest entry is malformed
      tool-version/version-mismatch      <PREFIX>_VERSION, a gh-aw lock compiler_version,
                                         or a lockProject's pyproject.toml or uv.lock differs
      tool-version/checksum-mismatch     <PREFIX>[_<ARCH>]_SHA256 is not a manifest digest, or a
                                         manifest digest is missing from a lockProject's uv.lock
      tool-version/commit-mismatch       <PREFIX>_URL lacks the manifest commit
      tool-version/image-mismatch        a gh-aw-firewall image tag or digest differs
      tool-version/unregistered-tool     a file pins <NAME>_VERSION with a matching
                                         <NAME>_SHA256 but the manifest has no such tool
      tool-version/unpinned-install      a step uses astral-sh/setup-uv instead of the
                                         manifest-verified ./.github/actions/setup-uv
      tool-version/runtime-invalid       .node-version or .python-version does not hold
                                         exactly one X.Y.Z version
      tool-version/runtime-mismatch      a setup-node or setup-python step reads another
                                         file or pins a different literal, or a
                                         devcontainer runtime feature differs
      tool-version/runtime-unpinned      a setup-node or setup-python step sets no version,
                                         or its version file is missing

    Writes a console summary, optional SARIF (tool name hve-tool-version-consistency),
    and exits 1 when any finding exists.

.PARAMETER RepoRoot
    Repository root. Defaults to the git top-level directory.

.PARAMETER ManifestPath
    Tool manifest. Defaults to scripts/security/tool-checksums.json under RepoRoot.

.PARAMETER SarifPath
    Optional SARIF output path.

.EXAMPLE
    ./scripts/security/Test-ToolVersionConsistency.ps1 -SarifPath logs/tool-version-consistency.sarif
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [string]$SarifPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/SecurityHelpers.psm1') -Force

$script:ToolName = 'hve-tool-version-consistency'
$script:Verifications = @('published-checksums', 'attestation', 'release-digest', 'pypi', 'oci-digest')
$script:ArchTokens = 'AMD64|ARM64|X86_64|AARCH64|X64'
$script:Rules = @(
    @{ id = 'tool-version/manifest-invalid'; name = 'ManifestInvalid'; description = 'A tool manifest entry is missing a field or has an invalid value.'; level = 'error' }
    @{ id = 'tool-version/version-mismatch'; name = 'VersionMismatch'; description = 'A hard-coded tool version differs from the tool manifest.'; level = 'error' }
    @{ id = 'tool-version/checksum-mismatch'; name = 'ChecksumMismatch'; description = 'A hard-coded tool checksum is not a digest recorded in the tool manifest.'; level = 'error' }
    @{ id = 'tool-version/commit-mismatch'; name = 'CommitMismatch'; description = 'A tool download URL does not use the commit recorded in the tool manifest.'; level = 'error' }
    @{ id = 'tool-version/image-mismatch'; name = 'ImageMismatch'; description = 'A container image tag or digest differs from the tool manifest.'; level = 'error' }
    @{ id = 'tool-version/unregistered-tool'; name = 'UnregisteredTool'; description = 'A file pins a downloaded tool version and checksum that the tool manifest does not register.'; level = 'error' }
    @{ id = 'tool-version/unpinned-install'; name = 'UnpinnedInstall'; description = 'A tool install bypasses the manifest-verified installer.'; level = 'error' }
    @{ id = 'tool-version/runtime-invalid'; name = 'RuntimeInvalid'; description = 'A runtime version file does not hold exactly one X.Y.Z version.'; level = 'error' }
    @{ id = 'tool-version/runtime-mismatch'; name = 'RuntimeMismatch'; description = 'A runtime version differs from its version file or reads another file.'; level = 'error' }
    @{ id = 'tool-version/runtime-unpinned'; name = 'RuntimeUnpinned'; description = 'A runtime setup step has no exact version from the runtime version file.'; level = 'error' }
)

# Each runtime has one exact version in a root version file. setup-node and
# setup-python read it with their *-version-file input; a job without a checkout
# may use a literal that equals it. The devcontainer feature must match it too.
$script:Runtimes = @(
    @{ Name = 'node'; File = '.node-version'; Action = 'actions/setup-node'; VersionKey = 'node-version'; FileKey = 'node-version-file'; Feature = 'ghcr.io/devcontainers/features/node' }
    @{ Name = 'python'; File = '.python-version'; Action = 'actions/setup-python'; VersionKey = 'python-version'; FileKey = 'python-version-file'; Feature = 'ghcr.io/devcontainers/features/python' }
)

function New-Finding {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RuleId,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$File,
        [Parameter()][int]$Line = 1
    )
    [pscustomobject]@{ RuleId = $RuleId; Message = $Message; File = $File; Line = $Line }
}

function Get-LineNumber {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][int]$Index
    )
    return ([regex]::Matches($Content.Substring(0, $Index), "`n")).Count + 1
}

function Get-ToolManifestFinding {
    <#
    .SYNOPSIS
        Validates manifest entries and returns findings for malformed ones.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][string]$ManifestFile
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $prefixes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $hex = '^[0-9a-f]{64}$'
    foreach ($tool in @($Manifest.tools)) {
        $label = if ($tool.name) { $tool.name } else { '(unnamed)' }
        $problems = [System.Collections.Generic.List[string]]::new()
        foreach ($field in 'name', 'repo', 'version', 'verification') {
            if (-not $tool.$field) { $problems.Add("missing '$field'") }
        }
        if ($tool.name -and -not $names.Add([string]$tool.name)) { $problems.Add('duplicate name') }
        if ($tool.repo -and $tool.repo -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') { $problems.Add("'repo' must be owner/name") }
        if ($tool.version -and $tool.version -match '^v') { $problems.Add("'version' must not start with v") }
        if ($tool.verification -and $tool.verification -cnotin $script:Verifications) { $problems.Add("'verification' must be one of: $($script:Verifications -join ', ')") }
        if ($tool.envPrefix) {
            if ($tool.envPrefix -cnotmatch '^[A-Z][A-Z0-9_]*$') { $problems.Add("'envPrefix' must be uppercase") }
            elseif (-not $prefixes.Add([string]$tool.envPrefix)) { $problems.Add('duplicate envPrefix') }
        }
        if ($tool.verification -eq 'oci-digest') {
            $images = @($tool.images.PSObject.Properties)
            if ($images.Count -eq 0) { $problems.Add("'images' is required for oci-digest") }
            foreach ($image in $images) {
                if ("$($image.Value)" -notmatch '^sha256:[0-9a-f]{64}$') { $problems.Add("image '$($image.Name)' needs a sha256: digest") }
            }
        }
        elseif ($tool.verification) {
            $digests = @($tool.sha256ByArch.PSObject.Properties)
            if (-not ($digests | Where-Object Name -EQ 'linux_amd64')) { $problems.Add("'sha256ByArch.linux_amd64' is required") }
            foreach ($digest in $digests) {
                if ("$($digest.Value)" -cnotmatch $hex) { $problems.Add("'sha256ByArch.$($digest.Name)' must be 64 lowercase hex characters") }
            }
            if ($tool.verification -in 'published-checksums', 'attestation', 'release-digest' -and -not $tool.registry) {
                foreach ($digest in $digests) {
                    if (-not $tool.assetTemplateByArch.($digest.Name)) { $problems.Add("'assetTemplateByArch.$($digest.Name)' is required") }
                }
            }
            if ($tool.verification -eq 'attestation' -and (-not $tool.attestation.repo -or -not $tool.attestation.signerWorkflow)) {
                $problems.Add("'attestation.repo' and 'attestation.signerWorkflow' are required")
            }
            if ($tool.verification -eq 'pypi' -and -not $tool.package) { $problems.Add("'package' is required for pypi") }
        }
        if ($tool.lockProject -and ($tool.registry -ne 'pypi' -or -not $tool.package)) { $problems.Add("'lockProject' needs registry 'pypi' and a 'package'") }
        if ($problems.Count -gt 0) {
            $findings.Add((New-Finding -RuleId 'tool-version/manifest-invalid' -Message "Tool '$label': $($problems -join '; ')." -File $ManifestFile))
        }
    }
    return $findings.ToArray()
}

function Get-LockProjectFinding {
    <#
    .SYNOPSIS
        Checks that each PyPI tool's locked uv project pins the manifest version and wheel digests.
    .DESCRIPTION
        For every manifest tool with a lockProject, pyproject.toml must pin
        package==version, and uv.lock must resolve that version and contain every
        manifest sha256, so the manifest, the lock, and staleness checks agree.
    .OUTPUTS
        PSCustomObject with Findings and the scanned relative paths.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestFile
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $scanned = [System.Collections.Generic.List[string]]::new()
    foreach ($tool in @($Manifest.tools | Where-Object { $_.lockProject -and $_.package })) {
        $project = ([string]$tool.lockProject).TrimEnd('/')
        $pyprojectRelative = "$project/pyproject.toml"
        $lockRelative = "$project/uv.lock"
        $pyprojectPath = Join-Path $RepoRoot $pyprojectRelative
        $lockPath = Join-Path $RepoRoot $lockRelative
        if (-not (Test-Path -LiteralPath $pyprojectPath) -or -not (Test-Path -LiteralPath $lockPath)) {
            $findings.Add((New-Finding -RuleId 'tool-version/manifest-invalid' -File $ManifestFile `
                        -Message "Tool '$($tool.name)': lockProject '$project' needs pyproject.toml and uv.lock."))
            continue
        }
        $scanned.Add($pyprojectRelative)
        $scanned.Add($lockRelative)
        $package = [regex]::Escape([string]$tool.package)

        $pyproject = (Get-Content -Raw -LiteralPath $pyprojectPath) -replace "`r`n", "`n"
        $pin = [regex]::Match($pyproject, "[""']$package==(?<v>[^""';\s]+)[""']", 'IgnoreCase')
        if (-not $pin.Success -or $pin.Groups['v'].Value -cne $tool.version) {
            $found = if ($pin.Success) { "pins $($pin.Groups['v'].Value)" } else { 'does not pin it with ==' }
            $line = if ($pin.Success) { Get-LineNumber $pyproject $pin.Index } else { 1 }
            $findings.Add((New-Finding -RuleId 'tool-version/version-mismatch' -File $pyprojectRelative -Line $line `
                        -Message "$($tool.package) $found here but scripts/security/tool-checksums.json pins $($tool.version)."))
        }

        $lock = (Get-Content -Raw -LiteralPath $lockPath) -replace "`r`n", "`n"
        $entry = [regex]::Match($lock, "(?m)^\[\[package\]\]\nname = ""$package""\nversion = ""(?<v>[^""]+)""", 'IgnoreCase')
        if (-not $entry.Success -or $entry.Groups['v'].Value -cne $tool.version) {
            $found = if ($entry.Success) { "resolves $($entry.Groups['v'].Value)" } else { 'does not resolve it' }
            $line = if ($entry.Success) { Get-LineNumber $lock $entry.Index } else { 1 }
            $findings.Add((New-Finding -RuleId 'tool-version/version-mismatch' -File $lockRelative -Line $line `
                        -Message "$($tool.package) $found here but scripts/security/tool-checksums.json pins $($tool.version). Run uv lock."))
        }
        foreach ($digest in @($tool.sha256ByArch.PSObject.Properties)) {
            if (-not $lock.Contains("sha256:$($digest.Value)")) {
                $findings.Add((New-Finding -RuleId 'tool-version/checksum-mismatch' -File $lockRelative `
                            -Message "$($tool.package) $($digest.Name) digest $($digest.Value) from scripts/security/tool-checksums.json is not in this uv.lock."))
            }
        }
    }
    return [pscustomobject]@{ Findings = $findings.ToArray(); Scanned = $scanned.ToArray() }
}

function Get-ToolFileFinding {
    <#
    .SYNOPSIS
        Compares hard-coded versions, checksums, and pins in one file to the manifest.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $tools = @($Manifest.tools)
    $byPrefix = @{}
    foreach ($tool in $tools) { if ($tool.envPrefix) { $byPrefix[[string]$tool.envPrefix] = $tool } }
    $isLock = $RelativePath -like '*.lock.yml'

    if (-not $isLock) {
        foreach ($prefix in $byPrefix.Keys) {
            $tool = $byPrefix[$prefix]
            $versionPattern = "(?m)\b$([regex]::Escape($prefix))_VERSION\s*[:=]\s*['""]?v?([0-9][^'""\s]*)"
            foreach ($match in [regex]::Matches($Content, $versionPattern)) {
                if ($match.Groups[1].Value -cne $tool.version) {
                    $findings.Add((New-Finding -RuleId 'tool-version/version-mismatch' -File $RelativePath -Line (Get-LineNumber $Content $match.Index) `
                                -Message "$($tool.name) is pinned to $($match.Groups[1].Value) here but $($tool.version) in scripts/security/tool-checksums.json."))
                }
            }

            $digests = @($tool.sha256ByArch.PSObject.Properties.Value)
            $checksumPattern = "(?m)\b$([regex]::Escape($prefix))(?:_(?:$($script:ArchTokens)))?_SHA256\s*[:=]\s*['""]?([0-9A-Fa-f]{64})\b"
            foreach ($match in [regex]::Matches($Content, $checksumPattern)) {
                if ($match.Groups[1].Value.ToLowerInvariant() -notin $digests) {
                    $findings.Add((New-Finding -RuleId 'tool-version/checksum-mismatch' -File $RelativePath -Line (Get-LineNumber $Content $match.Index) `
                                -Message "$($tool.name) checksum $($match.Groups[1].Value) is not recorded for version $($tool.version) in scripts/security/tool-checksums.json."))
                }
            }

            if ($tool.commit) {
                $urlPattern = "(?m)\b$([regex]::Escape($prefix))_URL\s*[:=]\s*['""]?(\S+)"
                foreach ($match in [regex]::Matches($Content, $urlPattern)) {
                    if ($match.Groups[1].Value -notmatch [regex]::Escape($tool.commit)) {
                        $findings.Add((New-Finding -RuleId 'tool-version/commit-mismatch' -File $RelativePath -Line (Get-LineNumber $Content $match.Index) `
                                    -Message "$($tool.name) URL does not use commit $($tool.commit) from scripts/security/tool-checksums.json."))
                    }
                }
            }
        }

        foreach ($match in [regex]::Matches($Content, "(?m)\b([A-Z][A-Z0-9_]*?)_VERSION\s*[:=]\s*['""]?v?[0-9]")) {
            $name = $match.Groups[1].Value
            if ($byPrefix.ContainsKey($name)) { continue }
            if ($Content -match "\b$([regex]::Escape($name))(?:_(?:$($script:ArchTokens)))?_SHA256\s*[:=]") {
                $findings.Add((New-Finding -RuleId 'tool-version/unregistered-tool' -File $RelativePath -Line (Get-LineNumber $Content $match.Index) `
                            -Message "$name is pinned with a checksum here but is not registered in scripts/security/tool-checksums.json."))
            }
        }

        foreach ($match in [regex]::Matches($Content, "(?m)^\s*(?:-\s+)?uses:\s*['""]?astral-sh/setup-uv(?:[@/'""\s]|$)")) {
            $findings.Add((New-Finding -RuleId 'tool-version/unpinned-install' -File $RelativePath -Line (Get-LineNumber $Content $match.Index) `
                        -Message 'astral-sh/setup-uv installs uv outside scripts/security/tool-checksums.json; use ./.github/actions/setup-uv.'))
        }
    }
    else {
        $ghAw = $tools | Where-Object name -EQ 'gh-aw' | Select-Object -First 1
        if ($ghAw) {
            foreach ($match in [regex]::Matches($Content, '"compiler_version"\s*:\s*"v?([^"]+)"')) {
                if ($match.Groups[1].Value -cne $ghAw.version) {
                    $findings.Add((New-Finding -RuleId 'tool-version/version-mismatch' -File $RelativePath -Line (Get-LineNumber $Content $match.Index) `
                                -Message "Compiled with gh-aw $($match.Groups[1].Value) but scripts/security/tool-checksums.json pins $($ghAw.version). Recompile with the pinned gh-aw."))
                }
            }
        }
        $awf = $tools | Where-Object name -EQ 'gh-aw-firewall' | Select-Object -First 1
        if ($awf) {
            foreach ($match in [regex]::Matches($Content, 'ghcr\.io/github/gh-aw-firewall/([a-z][a-z0-9-]*):([0-9][^@\s"'']*)(?:@(sha256:[0-9a-f]{64}))?')) {
                $image = $match.Groups[1].Value
                $line = Get-LineNumber $Content $match.Index
                if ($match.Groups[2].Value -cne $awf.version) {
                    $findings.Add((New-Finding -RuleId 'tool-version/image-mismatch' -File $RelativePath -Line $line `
                                -Message "gh-aw-firewall/$image is tagged $($match.Groups[2].Value) but scripts/security/tool-checksums.json pins $($awf.version)."))
                }
                elseif ($match.Groups[3].Success -and $match.Groups[3].Value -cne $awf.images.$image) {
                    $findings.Add((New-Finding -RuleId 'tool-version/image-mismatch' -File $RelativePath -Line $line `
                                -Message "gh-aw-firewall/$image digest $($match.Groups[3].Value) is not the digest recorded in scripts/security/tool-checksums.json."))
                }
            }
        }
    }

    return $findings.ToArray()
}

function Get-RuntimePin {
    <#
    .SYNOPSIS
        Reads each runtime version file and reports malformed ones.
    .OUTPUTS
        PSCustomObject with Pins (runtime name to version, or $null) and Findings.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $pins = @{}
    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($runtime in $script:Runtimes) {
        $pins[$runtime.Name] = $null
        $path = Join-Path $RepoRoot $runtime.File
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $lines = @((Get-Content -LiteralPath $path) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($lines.Count -eq 1 -and $lines[0] -match '^\d+\.\d+\.\d+$') {
            $pins[$runtime.Name] = $lines[0]
        }
        else {
            $findings.Add((New-Finding -RuleId 'tool-version/runtime-invalid' -File $runtime.File `
                        -Message "$($runtime.File) must hold exactly one X.Y.Z $($runtime.Name) version."))
        }
    }
    return [pscustomobject]@{ Pins = $pins; Findings = $findings.ToArray() }
}

function Get-RuntimeStepFinding {
    <#
    .SYNOPSIS
        Checks every setup-node and setup-python step in one workflow or action file.
    .DESCRIPTION
        Uses Get-WorkflowActionStep to read each runtime setup step's with: inputs
        and requires the runtime's *-version-file input to name the root version
        file or a literal version input to equal its pin.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][hashtable]$Pins
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($step in @(Get-WorkflowActionStep -Content $Content -ActionPattern '^actions/setup-(?:node|python)$')) {
        $runtime = $script:Runtimes | Where-Object Action -EQ $step.Action | Select-Object -First 1
        $fileValue = $step.Inputs[$runtime.FileKey]
        $versionValue = $step.Inputs[$runtime.VersionKey]

        $pin = $Pins[$runtime.Name]
        $lineNumber = $step.Line
        if (-not $pin) {
            $findings.Add((New-Finding -RuleId 'tool-version/runtime-unpinned' -File $RelativePath -Line $lineNumber `
                        -Message "$($runtime.Action) has no exact version source: $($runtime.File) is missing or invalid."))
        }
        elseif ($null -ne $fileValue) {
            if (($fileValue -replace '^\./', '') -cne $runtime.File) {
                $findings.Add((New-Finding -RuleId 'tool-version/runtime-mismatch' -File $RelativePath -Line $lineNumber `
                            -Message "$($runtime.Action) reads $fileValue; read $($runtime.File), the single $($runtime.Name) version source."))
            }
        }
        elseif ($null -ne $versionValue) {
            if ($versionValue -cne $pin) {
                $findings.Add((New-Finding -RuleId 'tool-version/runtime-mismatch' -File $RelativePath -Line $lineNumber `
                            -Message "$($runtime.Action) pins $($runtime.Name) $versionValue but $($runtime.File) pins $pin. Use $($runtime.FileKey): $($runtime.File)."))
            }
        }
        else {
            $findings.Add((New-Finding -RuleId 'tool-version/runtime-unpinned' -File $RelativePath -Line $lineNumber `
                        -Message "$($runtime.Action) sets no version; add $($runtime.FileKey): $($runtime.File)."))
        }
    }
    return $findings.ToArray()
}

function Get-DevcontainerRuntimeFinding {
    <#
    .SYNOPSIS
        Compares devcontainer runtime feature versions to the runtime version files.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][hashtable]$Pins
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($runtime in $script:Runtimes) {
        $pattern = '"' + [regex]::Escape($runtime.Feature) + ':[^"]*"\s*:\s*\{(?<body>[^}]*)\}'
        foreach ($match in [regex]::Matches($Content, $pattern)) {
            $version = [regex]::Match($match.Groups['body'].Value, '"version"\s*:\s*"(?<v>[^"]*)"')
            $value = if ($version.Success) { $version.Groups['v'].Value } else { $null }
            $pin = $Pins[$runtime.Name]
            if (-not $pin -or $value -cne $pin) {
                $expected = if ($pin) { $pin } else { "an exact version in $($runtime.File)" }
                $shown = if ($value) { $value } else { 'no version' }
                $findings.Add((New-Finding -RuleId 'tool-version/runtime-mismatch' -File $RelativePath -Line (Get-LineNumber $Content $match.Index) `
                            -Message "The $($runtime.Name) devcontainer feature uses $shown but needs $expected."))
            }
        }
    }
    return $findings.ToArray()
}

function Get-ScannedFile {
    <#
    .SYNOPSIS
        Lists repository-relative files the consistency check scans.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $files = [System.Collections.Generic.List[string]]::new()
    $workflows = Join-Path $RepoRoot '.github/workflows'
    if (Test-Path -LiteralPath $workflows) {
        $files.AddRange([string[]]@(Get-ChildItem -LiteralPath $workflows -File | Where-Object { $_.Extension -in '.yml', '.yaml' } | ForEach-Object FullName))
    }
    $actions = Join-Path $RepoRoot '.github/actions'
    if (Test-Path -LiteralPath $actions) {
        $files.AddRange([string[]]@(Get-ChildItem -LiteralPath $actions -Recurse -File | Where-Object { $_.Name -in 'action.yml', 'action.yaml' } | ForEach-Object FullName))
    }
    $devcontainer = Join-Path $RepoRoot '.devcontainer/scripts'
    if (Test-Path -LiteralPath $devcontainer) {
        $files.AddRange([string[]]@(Get-ChildItem -LiteralPath $devcontainer -File -Filter '*.sh' | ForEach-Object FullName))
    }
    $devcontainerJson = Join-Path $RepoRoot '.devcontainer/devcontainer.json'
    if (Test-Path -LiteralPath $devcontainerJson) {
        $files.Add((Resolve-Path -LiteralPath $devcontainerJson).Path)
    }
    $rootFull = (Resolve-Path -LiteralPath $RepoRoot).Path
    return @($files | Sort-Object | ForEach-Object { [System.IO.Path]::GetRelativePath($rootFull, $_) -replace '\\', '/' })
}

function Invoke-ToolVersionConsistency {
    <#
    .SYNOPSIS
        Runs the manifest and file checks.
    .OUTPUTS
        PSCustomObject with Findings, ScannedFiles, and ExitCode.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter()][string]$ManifestPath,
        [Parameter()][string]$SarifPath
    )

    if (-not $ManifestPath) { $ManifestPath = Join-Path $RepoRoot 'scripts/security/tool-checksums.json' }
    $manifestRelative = [System.IO.Path]::GetRelativePath((Resolve-Path -LiteralPath $RepoRoot).Path, (Resolve-Path -LiteralPath $ManifestPath).Path) -replace '\\', '/'
    $manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json

    $findings = [System.Collections.Generic.List[object]]::new()
    $findings.AddRange([object[]]@(Get-ToolManifestFinding -Manifest $manifest -ManifestFile $manifestRelative))
    $lockProjects = Get-LockProjectFinding -Manifest $manifest -RepoRoot $RepoRoot -ManifestFile $manifestRelative
    $findings.AddRange([object[]]@($lockProjects.Findings))
    $runtimePins = Get-RuntimePin -RepoRoot $RepoRoot
    $findings.AddRange([object[]]@($runtimePins.Findings))
    $scanned = @(Get-ScannedFile -RepoRoot $RepoRoot)
    foreach ($relative in $scanned) {
        $content = (Get-Content -Raw -LiteralPath (Join-Path $RepoRoot $relative)) -replace "`r`n", "`n"
        if ($null -eq $content) { $content = '' }
        if ($relative -eq '.devcontainer/devcontainer.json') {
            $findings.AddRange([object[]]@(Get-DevcontainerRuntimeFinding -RelativePath $relative -Content $content -Pins $runtimePins.Pins))
            continue
        }
        $findings.AddRange([object[]]@(Get-ToolFileFinding -Manifest $manifest -RelativePath $relative -Content $content))
        if ($relative -like '*.yml' -or $relative -like '*.yaml') {
            $findings.AddRange([object[]]@(Get-RuntimeStepFinding -RelativePath $relative -Content $content -Pins $runtimePins.Pins))
        }
    }

    if ($SarifPath) {
        $directory = Split-Path -Parent $SarifPath
        if ($directory -and -not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
        ConvertTo-SecuritySarif -ToolName $script:ToolName -Rules $script:Rules -Findings $findings.ToArray() |
            ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $SarifPath -Encoding utf8NoBOM
    }

    return [pscustomobject]@{
        Findings     = $findings.ToArray()
        ScannedFiles = @($scanned) + @($lockProjects.Scanned)
        ExitCode     = $(if ($findings.Count -eq 0) { 0 } else { 1 })
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not $RepoRoot) {
            $RepoRoot = git rev-parse --show-toplevel 2>$null
            if (-not $RepoRoot) { $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
        }
        $result = Invoke-ToolVersionConsistency -RepoRoot $RepoRoot -ManifestPath $ManifestPath -SarifPath $SarifPath
        foreach ($finding in $result.Findings) {
            Write-Output "$($finding.File):$($finding.Line): [$($finding.RuleId)] $($finding.Message)"
        }
        Write-Output "Tool version consistency: $(@($result.Findings).Count) finding(s) across $(@($result.ScannedFiles).Count) file(s)."
        exit $result.ExitCode
    }
    catch {
        Write-Error -ErrorAction Continue "Test-ToolVersionConsistency failed: $($_.Exception.Message)"
        exit 1
    }
}
