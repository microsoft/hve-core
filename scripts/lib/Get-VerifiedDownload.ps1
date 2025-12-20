<#
.SYNOPSIS
    Downloads and verifies artifacts using SHA256 checksums.

.DESCRIPTION
    Securely downloads files from URLs and verifies their integrity using
    SHA256 checksums before saving or extracting.

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
    Get-VerifiedDownload -Url "https://example.com/tool.tar.gz" -ExpectedSHA256 "abc123..." -OutputPath "./tool.tar.gz"

.EXAMPLE
    Get-VerifiedDownload -Url "https://example.com/tool.tar.gz" -ExpectedSHA256 "abc123..." -OutputPath "./tool.tar.gz" -Extract -ExtractPath "./tools"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedSHA256,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Extract,

    [Parameter(Mandatory = $false)]
    [string]$ExtractPath
)

$ErrorActionPreference = 'Stop'

$tempFile = [System.IO.Path]::GetTempFileName()

try {
    Write-Host "Downloading: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing

    Write-Host "Verifying SHA256: $ExpectedSHA256"
    $actualHash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash

    if ($actualHash -ne $ExpectedSHA256.ToUpper()) {
        Write-Error "Checksum verification failed!`nExpected: $ExpectedSHA256`nActual:   $actualHash"
        exit 1
    }

    if ($Extract -and $ExtractPath) {
        Write-Host "Extracting to: $ExtractPath"
        if (-not (Test-Path $ExtractPath)) {
            New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
        }
        Expand-Archive -Path $tempFile -DestinationPath $ExtractPath -Force
    }
    else {
        $outputDir = Split-Path -Parent $OutputPath
        if ($outputDir -and -not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        Move-Item -Path $tempFile -Destination $OutputPath -Force
    }

    Write-Host "Download verified and complete" -ForegroundColor Green
}
finally {
    if (Test-Path $tempFile) {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
}
