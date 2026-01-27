<#
.SYNOPSIS
    Downloads and verifies artifacts using SHA256 checksums.

.DESCRIPTION
    Securely downloads files from URLs and verifies their integrity using
    SHA256 checksums before saving or extracting. Contains pure functions
    for testability and an I/O wrapper for orchestration.

.PARAMETER Url
    URL to download from.

.PARAMETER ExpectedSHA256
    Expected SHA256 checksum of the file.

.PARAMETER OutputPath   
    Path where the downloaded file will be saved.

.PARAMETER Extract
    Extract the archive after verification.

.PARAMETER ExtractPath
    Destination directory for extraction.

.EXAMPLE
    .\Get-VerifiedDownload.ps1 -Url "https://example.com/tool.tar.gz" -ExpectedSHA256 "abc123..." -OutputPath "./tool.tar.gz"

.EXAMPLE
    .\Get-VerifiedDownload.ps1 -Url "https://example.com/tool.tar.gz" -ExpectedSHA256 "abc123..." -OutputPath "./tool.tar.gz" -Extract -ExtractPath "./tools"

.EXAMPLE
    . .\Get-VerifiedDownload.ps1
    Invoke-VerifiedDownload -Url "https://example.com/file.zip" -DestinationDirectory "C:\downloads" -ExpectedHash "abc123..."
#>

#region Script Parameters

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Url,

    [Parameter(Mandatory = $false)]
    [string]$ExpectedSHA256,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Extract,

    [Parameter(Mandatory = $false)]
    [string]$ExtractPath
)

#endregion

#region Pure Functions

function Get-FileHashValue {
    <#
    .SYNOPSIS
        Computes the hash of a file using the specified algorithm.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('SHA256', 'SHA384', 'SHA512')]
        [string]$Algorithm
    )

    $hashResult = Get-FileHash -Path $Path -Algorithm $Algorithm
    return $hashResult.Hash
}

function Test-HashMatch {
    <#
    .SYNOPSIS
        Compares two hash strings for equality (case-insensitive).
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$ComputedHash,

        [Parameter(Mandatory)]
        [string]$ExpectedHash
    )

    return $ComputedHash.ToUpperInvariant() -eq $ExpectedHash.ToUpperInvariant()
}

function Get-DownloadTargetPath {
    <#
    .SYNOPSIS
        Resolves the target file path for a download operation.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$DestinationDirectory,

        [Parameter()]
        [string]$FileName
    )

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        $uri = [System.Uri]::new($Url)
        $FileName = [System.IO.Path]::GetFileName($uri.LocalPath)
    }

    return [System.IO.Path]::Combine($DestinationDirectory, $FileName)
}

function Test-ExistingFileValid {
    <#
    .SYNOPSIS
        Checks if an existing file matches the expected hash.
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ExpectedHash,

        [Parameter(Mandatory)]
        [ValidateSet('SHA256', 'SHA384', 'SHA512')]
        [string]$Algorithm
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        return $false
    }

    $computedHash = Get-FileHashValue -Path $Path -Algorithm $Algorithm
    return Test-HashMatch -ComputedHash $computedHash -ExpectedHash $ExpectedHash
}

function New-DownloadResult {
    <#
    .SYNOPSIS
        Creates a standardized download result object.
    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [bool]$WasDownloaded,

        [Parameter(Mandatory)]
        [bool]$HashVerified
    )

    return @{
        Path         = $Path
        WasDownloaded = $WasDownloaded
        HashVerified = $HashVerified
    }
}

function Get-ArchiveType {
    <#
    .SYNOPSIS
        Determines the archive type from a URL or file path.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    switch -Regex ($Path) {
        '\.zip$' { return 'zip' }
        '\.(tar\.gz|tgz)$' { return 'tar.gz' }
        '\.tar$' { return 'tar' }
        default { return 'unknown' }
    }
}

function Test-TarAvailable {
    <#
    .SYNOPSIS
        Tests if the tar command is available.
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tarCmd = Get-Command -Name 'tar' -ErrorAction SilentlyContinue
    return $null -ne $tarCmd
}

#endregion

#region I/O Wrapper Function

function Invoke-VerifiedDownload {
    <#
    .SYNOPSIS
        Downloads and verifies a file with hash validation.
    .DESCRIPTION
        I/O wrapper that orchestrates download operations using pure functions
        for logic and handles all file system and network operations.
    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$DestinationDirectory,

        [Parameter(Mandatory)]
        [string]$ExpectedHash,

        [Parameter()]
        [ValidateSet('SHA256', 'SHA384', 'SHA512')]
        [string]$Algorithm = 'SHA256',

        [Parameter()]
        [string]$FileName,

        [Parameter()]
        [switch]$Extract,

        [Parameter()]
        [string]$ExtractPath
    )

    $targetPath = Get-DownloadTargetPath -Url $Url -DestinationDirectory $DestinationDirectory -FileName $FileName

    # Check if valid file already exists
    if (Test-Path $targetPath) {
        if (Test-ExistingFileValid -Path $targetPath -ExpectedHash $ExpectedHash -Algorithm $Algorithm) {
            Write-Verbose "File already exists and hash matches: $targetPath"
            return New-DownloadResult -Path $targetPath -WasDownloaded $false -HashVerified $true
        }
    }

    # Ensure destination directory exists
    if (-not (Test-Path $DestinationDirectory)) {
        New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
    }

    # Download to temp file first
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        Write-Host "Downloading: $Url"
        Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing

        $computedHash = Get-FileHashValue -Path $tempFile -Algorithm $Algorithm
        $verified = Test-HashMatch -ComputedHash $computedHash -ExpectedHash $ExpectedHash

        if (-not $verified) {
            throw "Checksum verification failed!`nExpected: $ExpectedHash`nActual:   $computedHash"
        }

        # Handle extraction or move
        if ($Extract) {
            $extractDir = if ($ExtractPath) { $ExtractPath } else { $DestinationDirectory }
            if (-not (Test-Path $extractDir)) {
                New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            }

            $archiveType = Get-ArchiveType -Path $Url
            switch ($archiveType) {
                'zip' {
                    Write-Verbose "Extracting ZIP archive to $extractDir"
                    Expand-Archive -Path $tempFile -DestinationPath $extractDir -Force
                }
                'tar.gz' {
                    if (-not (Test-TarAvailable)) {
                        throw "tar command not available for .tar.gz extraction"
                    }
                    Write-Verbose "Extracting tar.gz archive to $extractDir"
                    tar -xzf $tempFile -C $extractDir
                    if ($LASTEXITCODE -ne 0) {
                        throw "tar extraction failed with exit code $LASTEXITCODE"
                    }
                }
                'tar' {
                    if (-not (Test-TarAvailable)) {
                        throw "tar command not available for .tar extraction"
                    }
                    Write-Verbose "Extracting tar archive to $extractDir"
                    tar -xf $tempFile -C $extractDir
                    if ($LASTEXITCODE -ne 0) {
                        throw "tar extraction failed with exit code $LASTEXITCODE"
                    }
                }
                default {
                    throw "Unsupported archive format for '$Url'. Supported: .zip, .tar.gz, .tgz, .tar"
                }
            }
        }
        else {
            Move-Item -Path $tempFile -Destination $targetPath -Force
        }

        Write-Host "Download verified and complete" -ForegroundColor Green
        return New-DownloadResult -Path $targetPath -WasDownloaded $true -HashVerified $true
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion

#region Main Execution
try {
    # Only execute when invoked directly (not dot-sourced)
    if ($MyInvocation.InvocationName -ne '.') {
        # Require parameters for direct invocation
        if (-not $Url -or -not $ExpectedSHA256 -or -not $OutputPath) {
            Write-Error "When invoking directly, -Url, -ExpectedSHA256, and -OutputPath are required."
            exit 1
        }

        $ErrorActionPreference = 'Stop'

        # Resolve destination directory and file name from OutputPath
        $destinationDir = Split-Path -Parent $OutputPath
        if (-not $destinationDir) {
            $destinationDir = $PWD.Path
        }
        $fileName = Split-Path -Leaf $OutputPath

        # Determine extract path
        $extractDir = $null
        if ($Extract) {
            $extractDir = if ($ExtractPath) { $ExtractPath } else { $destinationDir }
        }

        # Call the I/O wrapper function with script parameters
        $result = Invoke-VerifiedDownload `
            -Url $Url `
            -DestinationDirectory $destinationDir `
            -ExpectedHash $ExpectedSHA256 `
            -FileName $fileName `
            -Extract:$Extract `
            -ExtractPath $extractDir

        # Output the result for callers
        $result
        exit 0
    }
}
catch {
    Write-Error "Get Verified Download failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion
