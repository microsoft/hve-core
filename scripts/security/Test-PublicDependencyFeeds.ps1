#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Validates that committed dependency metadata uses canonical public feeds.

.DESCRIPTION
    Scans npm, Python, and uv dependency manifests and lockfiles for package
    source URLs. Fails when a source uses a non-public host, plain HTTP,
    embedded credentials, or a nonliteral npm registry value. Npm registry
    declarations must use the canonical public npm registry. Writes structured
    results to logs/public-dependency-feeds-results.json.

.PARAMETER RepoRoot
    Repository root to scan. Defaults to the root containing this script.

.PARAMETER OutputPath
    JSON results path. Defaults to logs/public-dependency-feeds-results.json.

.PARAMETER FailOnViolation
    Exit nonzero when a prohibited source is found.

.EXAMPLE
    ./scripts/security/Test-PublicDependencyFeeds.ps1 -FailOnViolation

.NOTES
    Runs via: npm run lint:public-dependency-feeds
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnViolation
)

$ErrorActionPreference = 'Stop'

#region Functions

function Test-DependencySourceLine {
    <#
    .SYNOPSIS
        Determines whether a line can declare a dependency source URL.
    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Line
    )

    $leafName = Split-Path -Leaf $Path
    switch -Regex ($leafName) {
        '^package\.json$' {
            return $Line -match '"registry"\s*:' -or $Line -match '"[^"\r\n]+"\s*:\s*"(?:git\+)?https?://'
        }
        '^(package-lock|npm-shrinkwrap)\.json$' {
            return $Line -match '"resolved"\s*:' -or $Line -match '"integrity"\s*:'
        }
        '^\.npmrc$' {
            return $Line -match '^\s*(?:@[^:]+:)?registry\s*='
        }
        '^uv\.lock$' {
            return $Line -match '\b(?:registry|url)\s*='
        }
        '^pyproject\.toml$' {
            return $Line -match '\b(?:index-url|extra-index-url|registry|url)\s*='
        }
        '^requirements.*\.txt$' {
            return $Line -match '(?:https?|git\+https)://'
        }
        default {
            return $false
        }
    }
}

function Invoke-PublicDependencyFeedScan {
    <#
    .SYNOPSIS
        Scans dependency metadata and returns validation results.
    .OUTPUTS
        [pscustomobject]
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    # Keep this enforcement list aligned with the public ecosystems described in
    # .github/instructions/dependency-feeds.instructions.md.
    $allowedHosts = @(
        'api.github.com',
        'api.nuget.org',
        'crates.io',
        'download-r2.pytorch.org',
        'download.pytorch.org',
        'files.pythonhosted.org',
        'github.com',
        'github-releases.githubusercontent.com',
        'index.crates.io',
        'objects.githubusercontent.com',
        'powershellgallery.com',
        'proxy.golang.org',
        'pypi.org',
        'registry.npmjs.org',
        'repo.packagist.org',
        'rubygems.org',
        'static.crates.io',
        'sum.golang.org',
        'www.nuget.org',
        'www.powershellgallery.com'
    )

    $pathPattern = '(^|/)(package\.json|package-lock\.json|npm-shrinkwrap\.json|uv\.lock|pyproject\.toml|requirements[^/]*\.txt|\.npmrc)$'
    $violations = [System.Collections.Generic.List[object]]::new()
    $sourceCount = 0

    $trackedFiles = @(& git -C $RepoRoot ls-files --cached --others --exclude-standard | Where-Object {
        $_ -match $pathPattern
    })
    if ($LASTEXITCODE -ne 0) {
        throw 'git ls-files failed while discovering dependency metadata.'
    }

    foreach ($relativePath in $trackedFiles) {
        $fullPath = Join-Path $RepoRoot $relativePath
        if (-not (Test-Path -LiteralPath $fullPath)) {
            continue
        }

        $lines = @(Get-Content -LiteralPath $fullPath)
        for ($index = 0; $index -lt $lines.Count; $index++) {
            $line = $lines[$index]
            if (-not (Test-DependencySourceLine -Path $relativePath -Line $line)) {
                continue
            }

            $urls = @([regex]::Matches($line, '(?:git\+)?https?://[^\s"''<>\)\],]+') | ForEach-Object {
                $_.Value -replace '^git\+', ''
            })

            $leafName = Split-Path -Leaf $relativePath

            # Lockfile integrity values must use SHA-512. Some proxy registries omit
            # dist.integrity and expose only dist.shasum, which makes npm record a
            # SHA-1 value and silently weakens subresource verification.
            if ($leafName -in @('package-lock.json', 'npm-shrinkwrap.json')) {
                # npm lockfiles currently emit one SRI hash even though SRI permits
                # multiple space-separated algorithms.
                $integrityMatch = [regex]::Match($line, '"integrity"\s*:\s*"(?<algorithm>[^-"]+)-')
                if ($integrityMatch.Success) {
                    $sourceCount++
                    $algorithm = $integrityMatch.Groups['algorithm'].Value.ToLowerInvariant()
                    if ($algorithm -ne 'sha512') {
                        $violations.Add([pscustomobject]@{
                            file   = $relativePath
                            line   = $index + 1
                            source = $line.Trim()
                            reason = "lockfile integrity must use sha512, found '$algorithm'"
                        }) | Out-Null
                    }
                    continue
                }
            }

            $isNpmRegistryDeclaration = $leafName -eq '.npmrc' -or ($leafName -eq 'package.json' -and $line -match '"registry"\s*:')
            if ($isNpmRegistryDeclaration -and $urls.Count -eq 0) {
                $violations.Add([pscustomobject]@{
                    file   = $relativePath
                    line   = $index + 1
                    source = $line.Trim()
                    reason = 'npm registry values must be literal public HTTPS URLs'
                }) | Out-Null
                continue
            }

            foreach ($url in $urls) {
                $sourceCount++
                try {
                    $uri = [uri]$url
                }
                catch {
                    $violations.Add([pscustomobject]@{
                        file   = $relativePath
                        line   = $index + 1
                        source = $url
                        reason = 'dependency source URL is invalid'
                    }) | Out-Null
                    continue
                }

                $reason = if ($uri.Scheme -ne 'https') {
                    'dependency sources must use HTTPS'
                }
                elseif (-not [string]::IsNullOrEmpty($uri.UserInfo)) {
                    'dependency source URLs must not contain credentials'
                }
                elseif ($isNpmRegistryDeclaration -and $uri.Host.ToLowerInvariant() -ne 'registry.npmjs.org') {
                    'npm registry declarations must use https://registry.npmjs.org/'
                }
                elseif ($uri.Host.ToLowerInvariant() -notin $allowedHosts) {
                    "dependency source host '$($uri.Host)' is not an approved public registry"
                }
                else {
                    $null
                }

                if ($reason) {
                    $violations.Add([pscustomobject]@{
                        file   = $relativePath
                        line   = $index + 1
                        source = $url
                        reason = $reason
                    }) | Out-Null
                }
            }
        }
    }

    return [pscustomobject]@{
        filesScanned     = $trackedFiles.Count
        sourcesValidated = $sourceCount
        allowedHosts     = $allowedHosts
        violationCount   = $violations.Count
        violations       = $violations
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not $OutputPath) {
            $OutputPath = Join-Path $RepoRoot 'logs/public-dependency-feeds-results.json'
        }

        $outputDirectory = Split-Path -Parent $OutputPath
        if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }

        $result = Invoke-PublicDependencyFeedScan -RepoRoot $RepoRoot
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8

        if ($result.violationCount -gt 0) {
            Write-Host 'Dependency feed policy violations:' -ForegroundColor Red
            foreach ($violation in $result.violations) {
                Write-Host ("  {0}:{1} {2}" -f $violation.file, $violation.line, $violation.reason) -ForegroundColor Red
                Write-Host ("    {0}" -f $violation.source) -ForegroundColor DarkGray
            }
            Write-Host "Results: $OutputPath" -ForegroundColor Yellow
            if ($FailOnViolation) {
                exit 1
            }
        }
        else {
            Write-Host ("OK: {0} dependency source(s) across {1} file(s) use approved public feeds." -f $result.sourcesValidated, $result.filesScanned) -ForegroundColor Green
            Write-Host "Results: $OutputPath"
        }

        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Test-PublicDependencyFeeds failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
