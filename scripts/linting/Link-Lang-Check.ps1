<#
.SYNOPSIS
    Language Path Link Checker and Fixer

.DESCRIPTION
    This script finds and optionally fixes URLs in git-tracked text files that contain
    the language path segment 'en-us'. It helps maintain links that work regardless
    of user language settings by removing unnecessary language path segments.

    Functionality:
    - Scans git-tracked text files for URLs containing 'en-us'
    - Identifies link locations by file and line number
    - Optionally removes 'en-us/' from URLs to make them language-neutral
    - Reports changes in human-readable or JSON format

.PARAMETER Fix
    Fix URLs by removing "en-us/" instead of just reporting them

.PARAMETER ExcludePaths
    Glob patterns for paths to exclude from checking (e.g., 'scripts/tests/**')

.EXAMPLE
    # Search for URLs containing 'en-us' and output as JSON
    .\Link-Lang-Check.ps1

.EXAMPLE
    # Fix URLs by removing 'en-us/' with verbose output
    .\Link-Lang-Check.ps1 -Fix -Verbose

.NOTES
    The script is designed to help maintain documentation links that work regardless
    of the user's language settings in their browser.

    Dependencies:
    - git: Required for identifying text files under source control
    - PowerShell 5.1 or PowerShell 7+

    Returns:
    - JSON array or console output: When not in fix mode, outputs a JSON array of found links
                                   When in fix mode, outputs human-readable summary of changes

    See Also:
    - Microsoft documentation guidance on language neutrality: https://learn.microsoft.com/style-guide/urls-web-addresses
#>

[CmdletBinding()]
param(
    [switch]$Fix,
    [string[]]$ExcludePaths = @()
)

function Get-GitTextFile {
    <#
    .SYNOPSIS
        Get list of all text files under git source control, excluding binary files.

    .DESCRIPTION
        Uses git's built-in binary detection to exclude non-text files from processing.

    .OUTPUTS
        System.String[]
        A list of file paths to text files tracked by git.
    #>

    try {
        # Use git's binary detection with -I flag (--no-binary)
        $result = & git grep -I --name-only -e '' 2>&1

        if ($LASTEXITCODE -gt 1) {
            Write-Error "Error executing git grep: $result"
            return @()
        }

        if ($result -and $result.Count -gt 0) {
            return $result | Where-Object { $_ -is [string] -and $_.Trim() -ne '' }
        }

        return @()
    }
    catch {
        Write-Error "Error getting git text files: $_"
        return @()
    }
}

function Find-LinksInFile {
    <#
    .SYNOPSIS
        Find links with 'en-us' in them and return details.

    .DESCRIPTION
        Scans the specified file for URLs containing the 'en-us' path segment and
        collects information about each occurrence.

    .PARAMETER FilePath
        Path to the file to scan

    .OUTPUTS
        System.Object[]
        A list of objects, each containing information about a link:
        - File: The file path
        - LineNumber: The line number where the link appears
        - OriginalUrl: The original URL with 'en-us'
        - FixedUrl: The URL with 'en-us/' removed
    #>

    [CmdletBinding()]
    param(
        [string]$FilePath
    )

    $linksFound = @()

    try {
        $lines = @(Get-Content -Path $FilePath -Encoding UTF8 -ErrorAction Stop)
    }
    catch {
        Write-Verbose "Could not read $FilePath`: $_"
        return $linksFound
    }

    # Regular expression to find URLs containing "en-us/"
    $urlPattern = 'https?://[^\s<>"'']+?en-us/[^\s<>"'']+'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $urlMatches = [regex]::Matches($line, $urlPattern)

        foreach ($match in $urlMatches) {
            $linksFound += [PSCustomObject]@{
                File        = $FilePath
                LineNumber  = $i + 1
                OriginalUrl = $match.Value
                FixedUrl    = $match.Value -replace 'en-us/', ''
            }
        }
    }

    return $linksFound
}

function Repair-LinksInFile {
    <#
    .SYNOPSIS
        Fix links in a single file by removing 'en-us/' from URLs.

    .DESCRIPTION
        Opens the file, replaces URLs containing 'en-us/' with versions without it,
        and writes the changes back to the file.

    .PARAMETER FilePath
        Path to the file to modify

    .PARAMETER Links
        Array of link objects for the file, each containing:
        - OriginalUrl: The original URL to replace
        - FixedUrl: The URL to replace it with

    .OUTPUTS
        System.Boolean
        True if the file was modified, False otherwise
    #>

    [CmdletBinding()]
    param(
        [string]$FilePath,
        [PSCustomObject[]]$Links
    )

    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Verbose "Could not read $FilePath`: $_"
        return $false
    }

    # Replace each link
    $modifiedContent = $content
    foreach ($link in $Links) {
        $modifiedContent = $modifiedContent -replace [regex]::Escape($link.OriginalUrl), $link.FixedUrl
    }

    # Only write if changes were made
    if ($modifiedContent -ne $content) {
        try {
            Set-Content -Path $FilePath -Value $modifiedContent -Encoding UTF8 -NoNewline -ErrorAction Stop
            return $true
        }
        catch {
            Write-Verbose "Could not write to $FilePath`: $_"
            return $false
        }
    }
    return $false
}

function Repair-AllLink {
    <#
    .SYNOPSIS
        Fix all links in their respective files.

    .DESCRIPTION
        Groups links by file, then calls Repair-LinksInFile for each file.

    .PARAMETER AllLinks
        Array of all link objects found across files

    .OUTPUTS
        System.Int32
        Number of files that were successfully modified
    #>

    [CmdletBinding()]
    param(
        [PSCustomObject[]]$AllLinks
    )

    # Group links by file
    $linksByFile = $AllLinks | Group-Object -Property File
    $filesModified = 0

    # Fix links in each file
    foreach ($fileGroup in $linksByFile) {
        $filePath = $fileGroup.Name
        $links = $fileGroup.Group

        Write-Verbose "Fixing links in $filePath..."

        if (Repair-LinksInFile -FilePath $filePath -Links $links) {
            $filesModified++
        }
    }

    return $filesModified
}

function ConvertTo-JsonOutput {
    <#
    .SYNOPSIS
        Prepare links for JSON output by formatting as an array of link objects.

    .DESCRIPTION
        Creates a clean representation without internal fields used for processing.

    .PARAMETER Links
        The complete array of link objects

    .OUTPUTS
        System.Object[]
        An array of objects ready for JSON serialization, each containing:
        - File: The file path
        - LineNumber: The line number where the link appears
        - OriginalUrl: The original URL with 'en-us'
    #>

    [CmdletBinding()]
    param(
        [PSCustomObject[]]$Links
    )

    $jsonData = @()
    foreach ($link in $Links) {
        # Create a copy without the FixedUrl field
        $jsonData += [PSCustomObject]@{
            file         = $link.File
            line_number  = $link.LineNumber
            original_url = $link.OriginalUrl
        }
    }
    return $jsonData
}

#region Main Execution
try {
    if ($Verbose) {
        Write-Information "Getting list of git-tracked text files..." -InformationAction Continue
    }

    $files = Get-GitTextFile

    # Apply exclusion patterns
    if ($ExcludePaths.Count -gt 0) {
        $originalCount = $files.Count
        $files = $files | Where-Object {
            $filePath = $_
            $excluded = $false
            foreach ($pattern in $ExcludePaths) {
                if ($filePath -like $pattern) {
                    $excluded = $true
                    break
                }
            }
            -not $excluded
        }
        if ($Verbose) {
            $excludedCount = $originalCount - $files.Count
            Write-Information "Excluded $excludedCount files matching exclusion patterns" -InformationAction Continue
        }
    }

    if ($Verbose) {
        Write-Information "Found $($files.Count) git-tracked text files" -InformationAction Continue
    }

    $allLinks = @()

    foreach ($filePath in $files) {
        if (-not (Test-Path -Path $filePath -PathType Leaf)) {
            if ($Verbose) {
                Write-Warning "Skipping $filePath`: not a regular file"
            }
            continue
        }

        if ($Verbose) {
            Write-Verbose "Processing $filePath..."
        }

        $links = Find-LinksInFile -FilePath $filePath
        $allLinks += $links
    }

    # Report findings
    if ($allLinks.Count -gt 0) {
        if ($Fix) {
            # Human-readable output when fixing links
            if ($Verbose) {
                Write-Information "`nFound $($allLinks.Count) URLs containing 'en-us':`n" -InformationAction Continue
                foreach ($linkInfo in $allLinks) {
                    Write-Information "File: $($linkInfo.File), Line: $($linkInfo.LineNumber)" -InformationAction Continue
                    Write-Information "  URL: $($linkInfo.OriginalUrl)" -InformationAction Continue
                    Write-Information "" -InformationAction Continue
                }
            }

            $filesModified = Repair-AllLink -AllLinks $allLinks
            Write-Output "Fixed $($allLinks.Count) URLs in $filesModified files."

            if ($Verbose) {
                Write-Information "`nDetails of fixes:" -InformationAction Continue
                foreach ($linkInfo in $allLinks) {
                    Write-Information "File: $($linkInfo.File), Line: $($linkInfo.LineNumber)" -InformationAction Continue
                    Write-Information "  Original: $($linkInfo.OriginalUrl)" -InformationAction Continue
                    Write-Information "  Fixed: $($linkInfo.FixedUrl)" -InformationAction Continue
                    Write-Information "" -InformationAction Continue
                }
            }
        }
        else {
            # JSON output when not fixing links
            $jsonOutput = ConvertTo-JsonOutput -Links $allLinks
            Write-Output ($jsonOutput | ConvertTo-Json -Depth 3)
        }
    }
    else {
        if (-not $Fix) {
            # Empty JSON array if no links found
            Write-Output "[]"
        }
        else {
            Write-Output "No URLs containing 'en-us' were found."
        }
    }
    exit 0
}
catch {
    Write-Error "Link Lang Check failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion