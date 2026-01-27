#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Prepares the HVE Core VS Code extension for packaging.

.DESCRIPTION
    This script prepares the VS Code extension by:
    - Auto-discovering chat agents, prompts, and instruction files
    - Filtering agents by maturity level based on channel
    - Updating package.json with discovered components
    - Updating changelog if provided

    The package.json version is not modified.

.PARAMETER ChangelogPath
    Optional. Path to a changelog file to include in the package.

.PARAMETER Channel
    Optional. Release channel controlling which maturity levels are included.
    'Stable' (default): Only includes agents with maturity 'stable'.
    'PreRelease': Includes 'stable', 'preview', and 'experimental' maturity levels.

.PARAMETER DryRun
    Optional. If specified, shows what would be done without making changes.

.EXAMPLE
    ./Prepare-Extension.ps1
    # Prepares stable channel using existing version from package.json

.EXAMPLE
    ./Prepare-Extension.ps1 -Channel PreRelease
    # Prepares pre-release channel including experimental agents

.EXAMPLE
    ./Prepare-Extension.ps1 -ChangelogPath "./CHANGELOG.md"
    # Prepares with changelog

.NOTES
    Dependencies: PowerShell-Yaml module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ChangelogPath = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet('Stable', 'PreRelease')]
    [string]$Channel = 'Stable',

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

#region Pure Functions

function Get-AllowedMaturities {
    <#
    .SYNOPSIS
        Returns allowed maturity levels based on release channel.
    .DESCRIPTION
        Pure function that determines which maturity levels (stable, preview, experimental)
        are included in the extension package based on the specified channel.
    .PARAMETER Channel
        Release channel. 'Stable' returns only stable; 'PreRelease' includes all levels.
    .OUTPUTS
        [string[]] Array of allowed maturity level strings.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    if ($Channel -eq 'PreRelease') {
        return @('stable', 'preview', 'experimental')
    }
    return @('stable')
}

function Get-FrontmatterData {
    <#
    .SYNOPSIS
        Extracts description and maturity from YAML frontmatter.
    .DESCRIPTION
        Function that parses YAML frontmatter from a markdown file
        and returns a hashtable with description and maturity values.
    .PARAMETER FilePath
        Path to the markdown file to parse.
    .PARAMETER FallbackDescription
        Default description if none found in frontmatter.
    .OUTPUTS
        [hashtable] With description and maturity keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$FallbackDescription = ""
    )

    $content = Get-Content -Path $FilePath -Raw
    $description = ""
    $maturity = "stable"

    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        $yamlContent = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
        try {
            $data = ConvertFrom-Yaml -Yaml $yamlContent
            if ($data.ContainsKey('description')) {
                $description = $data.description
            }
            if ($data.ContainsKey('maturity')) {
                $maturity = $data.maturity
            }
        }
        catch {
            Write-Warning "Failed to parse YAML frontmatter in $(Split-Path -Leaf $FilePath): $_"
        }
    }

    return @{
        description = if ($description) { $description } else { $FallbackDescription }
        maturity    = $maturity
    }
}

function Test-PathsExist {
    <#
    .SYNOPSIS
        Validates that required paths exist for extension preparation.
    .DESCRIPTION
        Validation function that checks whether extension directory, package.json,
        and .github directory exist at the specified locations.
    .PARAMETER ExtensionDir
        Path to the extension directory.
    .PARAMETER PackageJsonPath
        Path to package.json file.
    .PARAMETER GitHubDir
        Path to .github directory.
    .OUTPUTS
        [hashtable] With IsValid bool, MissingPaths array, and ErrorMessages array.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionDir,

        [Parameter(Mandatory = $true)]
        [string]$PackageJsonPath,

        [Parameter(Mandatory = $true)]
        [string]$GitHubDir
    )

    $missingPaths = @()
    $errorMessages = @()

    if (-not (Test-Path $ExtensionDir)) {
        $missingPaths += $ExtensionDir
        $errorMessages += "Extension directory not found: $ExtensionDir"
    }
    if (-not (Test-Path $PackageJsonPath)) {
        $missingPaths += $PackageJsonPath
        $errorMessages += "package.json not found: $PackageJsonPath"
    }
    if (-not (Test-Path $GitHubDir)) {
        $missingPaths += $GitHubDir
        $errorMessages += ".github directory not found: $GitHubDir"
    }

    return @{
        IsValid       = ($missingPaths.Count -eq 0)
        MissingPaths  = $missingPaths
        ErrorMessages = $errorMessages
    }
}

function Get-DiscoveredAgents {
    <#
    .SYNOPSIS
        Discovers chat agent files from the agents directory.
    .DESCRIPTION
        Discovery function that scans the agents directory for .agent.md files,
        extracts frontmatter data, filters by maturity and exclusion list,
        and returns structured agent objects.
    .PARAMETER AgentsDir
        Path to the agents directory.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .PARAMETER ExcludedAgents
        Array of agent names to exclude from packaging.
    .OUTPUTS
        [hashtable] With Agents array, Skipped array, and DirectoryExists bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AgentsDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludedAgents = @()
    )

    $result = @{
        Agents          = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $AgentsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $agentFiles = Get-ChildItem -Path $AgentsDir -Filter "*.agent.md" | Sort-Object Name

    foreach ($agentFile in $agentFiles) {
        $agentName = $agentFile.BaseName -replace '\.agent$', ''

        if ($ExcludedAgents -contains $agentName) {
            $result.Skipped += @{ Name = $agentName; Reason = 'excluded' }
            continue
        }

        $frontmatter = Get-FrontmatterData -FilePath $agentFile.FullName -FallbackDescription "AI agent for $agentName"
        $maturity = $frontmatter.maturity

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $agentName; Reason = "maturity: $maturity" }
            continue
        }

        $result.Agents += [PSCustomObject]@{
            name        = $agentName
            path        = "./.github/agents/$($agentFile.Name)"
            description = $frontmatter.description
        }
    }

    return $result
}

function Get-DiscoveredPrompts {
    <#
    .SYNOPSIS
        Discovers prompt files from the prompts directory.
    .DESCRIPTION
        Discovery function that scans the prompts directory for .prompt.md files,
        extracts frontmatter data, filters by maturity, and returns structured
        prompt objects with relative paths.
    .PARAMETER PromptsDir
        Path to the prompts directory.
    .PARAMETER GitHubDir
        Path to the .github directory for relative path calculation.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .OUTPUTS
        [hashtable] With Prompts array, Skipped array, and DirectoryExists bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PromptsDir,

        [Parameter(Mandatory = $true)]
        [string]$GitHubDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities
    )

    $result = @{
        Prompts         = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $PromptsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $promptFiles = Get-ChildItem -Path $PromptsDir -Filter "*.prompt.md" -Recurse | Sort-Object Name

    foreach ($promptFile in $promptFiles) {
        $promptName = $promptFile.BaseName -replace '\.prompt$', ''
        $displayName = ($promptName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }
        $frontmatter = Get-FrontmatterData -FilePath $promptFile.FullName -FallbackDescription "Prompt for $displayName"
        $maturity = $frontmatter.maturity

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $promptName; Reason = "maturity: $maturity" }
            continue
        }

        $relativePath = [System.IO.Path]::GetRelativePath($GitHubDir, $promptFile.FullName) -replace '\\', '/'

        $result.Prompts += [PSCustomObject]@{
            name        = $promptName
            path        = "./.github/$relativePath"
            description = $frontmatter.description
        }
    }

    return $result
}

function Get-DiscoveredInstructions {
    <#
    .SYNOPSIS
        Discovers instruction files from the instructions directory.
    .DESCRIPTION
        Discovery function that scans the instructions directory for .instructions.md files,
        extracts frontmatter data, filters by maturity, and returns structured
        instruction objects with normalized paths.
    .PARAMETER InstructionsDir
        Path to the instructions directory.
    .PARAMETER GitHubDir
        Path to the .github directory for relative path calculation.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .OUTPUTS
        [hashtable] With Instructions array, Skipped array, and DirectoryExists bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstructionsDir,

        [Parameter(Mandatory = $true)]
        [string]$GitHubDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities
    )

    $result = @{
        Instructions    = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $InstructionsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $instructionFiles = Get-ChildItem -Path $InstructionsDir -Filter "*.instructions.md" -Recurse | Sort-Object Name

    foreach ($instrFile in $instructionFiles) {
        $baseName = $instrFile.BaseName -replace '\.instructions$', ''
        $instrName = "$baseName-instructions"
        $displayName = ($baseName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }
        $frontmatter = Get-FrontmatterData -FilePath $instrFile.FullName -FallbackDescription "Instructions for $displayName"
        $maturity = $frontmatter.maturity

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $instrName; Reason = "maturity: $maturity" }
            continue
        }

        $relativePathFromGitHub = [System.IO.Path]::GetRelativePath($GitHubDir, $instrFile.FullName)
        $normalizedRelativePath = (Join-Path ".github" $relativePathFromGitHub) -replace '\\', '/'

        $result.Instructions += [PSCustomObject]@{
            name        = $instrName
            path        = "./$normalizedRelativePath"
            description = $frontmatter.description
        }
    }

    return $result
}

function Update-PackageJsonContributes {
    <#
    .SYNOPSIS
        Updates package.json contributes section with discovered components.
    .DESCRIPTION
        Pure function that takes a package.json object and discovered components,
        returning a new object with the contributes section updated.
    .PARAMETER PackageJson
        The package.json object to update.
    .PARAMETER ChatAgents
        Array of discovered chat agent objects.
    .PARAMETER ChatPromptFiles
        Array of discovered prompt objects.
    .PARAMETER ChatInstructions
        Array of discovered instruction objects.
    .OUTPUTS
        [PSCustomObject] Updated package.json object.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PackageJson,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$ChatAgents,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$ChatPromptFiles,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$ChatInstructions
    )

    # Clone the object to avoid modifying the original
    $updated = $PackageJson | ConvertTo-Json -Depth 10 | ConvertFrom-Json

    # Ensure contributes section exists
    if (-not $updated.contributes) {
        $updated | Add-Member -NotePropertyName "contributes" -NotePropertyValue ([PSCustomObject]@{})
    }

    # Add or update contributes properties
    if ($null -eq $updated.contributes.chatAgents) {
        $updated.contributes | Add-Member -NotePropertyName "chatAgents" -NotePropertyValue $ChatAgents -Force
    } else {
        $updated.contributes.chatAgents = $ChatAgents
    }

    if ($null -eq $updated.contributes.chatPromptFiles) {
        $updated.contributes | Add-Member -NotePropertyName "chatPromptFiles" -NotePropertyValue $ChatPromptFiles -Force
    } else {
        $updated.contributes.chatPromptFiles = $ChatPromptFiles
    }

    if ($null -eq $updated.contributes.chatInstructions) {
        $updated.contributes | Add-Member -NotePropertyName "chatInstructions" -NotePropertyValue $ChatInstructions -Force
    } else {
        $updated.contributes.chatInstructions = $ChatInstructions
    }

    return $updated
}

#endregion Pure Functions

#region Main Execution
try {
    if ($MyInvocation.InvocationName -ne '.') {
        # Verify PowerShell-Yaml module is available (runtime check instead of #Requires)
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            Write-Error "Required module 'PowerShell-Yaml' is not installed. Install with: Install-Module -Name PowerShell-Yaml -Scope CurrentUser"
            exit 1
        }
        Import-Module PowerShell-Yaml -ErrorAction Stop

        # Define allowed maturity levels based on channel
        $allowedMaturities = Get-AllowedMaturities -Channel $Channel

        # Determine script and repo paths
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = (Get-Item "$ScriptDir/../..").FullName
    $ExtensionDir = Join-Path $RepoRoot "extension"
    $GitHubDir = Join-Path $RepoRoot ".github"
    $PackageJsonPath = Join-Path $ExtensionDir "package.json"

    Write-Host "📦 HVE Core Extension Preparer" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "   Channel: $Channel" -ForegroundColor Cyan
    Write-Host ""

    # Verify paths exist
    if (-not (Test-Path $ExtensionDir)) {
        Write-Error "Extension directory not found: $ExtensionDir"
        exit 1
    }

    if (-not (Test-Path $PackageJsonPath)) {
        Write-Error "package.json not found: $PackageJsonPath"
        exit 1
    }

    if (-not (Test-Path $GitHubDir)) {
        Write-Error ".github directory not found: $GitHubDir"
        exit 1
    }

    # Read current package.json
    Write-Host "📖 Reading package.json..." -ForegroundColor Yellow
    try {
        $packageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json
    } catch {
        Write-Error "Failed to parse package.json: $_`nPlease check $PackageJsonPath for JSON syntax errors."
        exit 1
    }

    # Validate package.json has required version field
    if (-not $packageJson.PSObject.Properties['version']) {
        Write-Error "package.json is missing required 'version' field"
        exit 1
    }

    # Use existing version from package.json
    $version = $packageJson.version

    # Validate version format
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        Write-Error "Invalid version format in package.json: '$version'. Expected semantic version format (e.g., 1.0.0)"
        exit 1
    }

    Write-Host "   Using version: $version" -ForegroundColor Green

    # Discover chat agents (excluding hve-core-installer which is for manual installation only)
    Write-Host ""
    Write-Host "🔍 Discovering chat agents..." -ForegroundColor Yellow
    $agentsDir = Join-Path $GitHubDir "agents"
    $chatAgents = @()

    # Agents to exclude from extension packaging
    $excludedAgents = @('hve-core-installer')

    if (Test-Path $agentsDir) {
        $agentFiles = Get-ChildItem -Path $agentsDir -Filter "*.agent.md" | Sort-Object Name

        foreach ($agentFile in $agentFiles) {
            # Extract agent name from filename (e.g., hve-core-installer.agent.md -> hve-core-installer)
            $agentName = $agentFile.BaseName -replace '\.agent$', ''

            # Skip excluded agents
            if ($excludedAgents -contains $agentName) {
                Write-Host "   ⏭️  $agentName (excluded)" -ForegroundColor DarkGray
                continue
            }

            # Extract frontmatter data
            $frontmatter = Get-FrontmatterData -FilePath $agentFile.FullName -FallbackDescription "AI agent for $agentName"
            $description = $frontmatter.description
            $maturity = $frontmatter.maturity

            # Filter by maturity based on channel
            if ($allowedMaturities -notcontains $maturity) {
                Write-Host "   ⏭️  $agentName (maturity: $maturity, skipped for $Channel)" -ForegroundColor DarkGray
                continue
            }

            $agent = [PSCustomObject]@{
                name        = $agentName
                path        = "./.github/agents/$($agentFile.Name)"
                description = $description
            }

            $chatAgents += $agent
            Write-Host "   ✅ $agentName" -ForegroundColor Green
        }
    } else {
        Write-Warning "Agents directory not found: $agentsDir"
    }

    # Discover prompts
    Write-Host ""
    Write-Host "🔍 Discovering prompts..." -ForegroundColor Yellow
    $promptsDir = Join-Path $GitHubDir "prompts"
    $chatPromptFiles = @()

    if (Test-Path $promptsDir) {
        $promptFiles = Get-ChildItem -Path $promptsDir -Filter "*.prompt.md" -Recurse | Sort-Object Name

        foreach ($promptFile in $promptFiles) {
            # Extract prompt name from filename (e.g., git-commit.prompt.md -> git-commit)
            $promptName = $promptFile.BaseName -replace '\.prompt$', ''

            # Extract frontmatter data
            $displayName = ($promptName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }
            $frontmatter = Get-FrontmatterData -FilePath $promptFile.FullName -FallbackDescription "Prompt for $displayName"
            $description = $frontmatter.description
            $maturity = $frontmatter.maturity

            # Filter by maturity based on channel
            if ($allowedMaturities -notcontains $maturity) {
                Write-Host "   ⏭️  $promptName (maturity: $maturity, skipped for $Channel)" -ForegroundColor DarkGray
                continue
            }

            # Calculate relative path from .github
            $relativePath = [System.IO.Path]::GetRelativePath($GitHubDir, $promptFile.FullName) -replace '\\', '/'

            $prompt = [PSCustomObject]@{
                name        = $promptName
                path        = "./.github/$relativePath"
                description = $description
            }

            $chatPromptFiles += $prompt
            Write-Host "   ✅ $promptName" -ForegroundColor Green
        }
    } else {
        Write-Warning "Prompts directory not found: $promptsDir"
    }

    # Discover instruction files
    Write-Host ""
    Write-Host "🔍 Discovering instruction files..." -ForegroundColor Yellow
    $instructionsDir = Join-Path $GitHubDir "instructions"
    $chatInstructions = @()

    if (Test-Path $instructionsDir) {
        $instructionFiles = Get-ChildItem -Path $instructionsDir -Filter "*.instructions.md" -Recurse | Sort-Object Name

        foreach ($instrFile in $instructionFiles) {
            # Extract instruction name from filename (e.g., commit-message.instructions.md -> commit-message-instructions)
            $baseName = $instrFile.BaseName -replace '\.instructions$', ''
            $instrName = "$baseName-instructions"

            # Extract frontmatter data
            $displayName = ($baseName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }
            $frontmatter = Get-FrontmatterData -FilePath $instrFile.FullName -FallbackDescription "Instructions for $displayName"
            $description = $frontmatter.description
            $maturity = $frontmatter.maturity

            # Filter by maturity based on channel
            if ($allowedMaturities -notcontains $maturity) {
                Write-Host "   ⏭️  $instrName (maturity: $maturity, skipped for $Channel)" -ForegroundColor DarkGray
                continue
            }

            # Calculate relative path from .github using cross-platform APIs
            $relativePathFromGitHub = [System.IO.Path]::GetRelativePath($GitHubDir, $instrFile.FullName)
            $normalizedRelativePath = (Join-Path ".github" $relativePathFromGitHub) -replace '\\', '/'

            $instruction = [PSCustomObject]@{
                name        = $instrName
                path        = "./$normalizedRelativePath"
                description = $description
            }

            $chatInstructions += $instruction
            Write-Host "   ✅ $instrName" -ForegroundColor Green
        }
    } else {
        Write-Warning "Instructions directory not found: $instructionsDir"
    }

    # Update package.json
    Write-Host ""
    Write-Host "📝 Updating package.json..." -ForegroundColor Yellow

    # Ensure contributes section exists
    if (-not $packageJson.contributes) {
        $packageJson | Add-Member -NotePropertyName "contributes" -NotePropertyValue ([PSCustomObject]@{})
    }

    # Update chatAgents
    $packageJson.contributes.chatAgents = $chatAgents
    Write-Host "   Updated chatAgents: $($chatAgents.Count) agents" -ForegroundColor Green

    # Update chatPromptFiles
    $packageJson.contributes.chatPromptFiles = $chatPromptFiles
    Write-Host "   Updated chatPromptFiles: $($chatPromptFiles.Count) prompts" -ForegroundColor Green

    # Update chatInstructions
    $packageJson.contributes.chatInstructions = $chatInstructions
    Write-Host "   Updated chatInstructions: $($chatInstructions.Count) files" -ForegroundColor Green

    if ($DryRun) {
        Write-Host ""
        Write-Host "🔍 DRY RUN - Would write the following package.json:" -ForegroundColor Magenta
        Write-Host ($packageJson | ConvertTo-Json -Depth 10)
        Write-Host ""
        Write-Host "🔍 DRY RUN - No changes made" -ForegroundColor Magenta
        exit 0
    }

    # Write updated package.json
    $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $PackageJsonPath -Encoding UTF8NoBOM
    Write-Host "   Saved package.json" -ForegroundColor Green

    # Handle changelog if provided
    if ($ChangelogPath) {
        Write-Host ""
        Write-Host "📋 Processing changelog..." -ForegroundColor Yellow

        if (Test-Path $ChangelogPath) {
            $changelogDest = Join-Path $ExtensionDir "CHANGELOG.md"
            Copy-Item -Path $ChangelogPath -Destination $changelogDest -Force
            Write-Host "   Copied changelog to extension directory" -ForegroundColor Green
        } else {
            Write-Warning "Changelog file not found: $ChangelogPath"
        }
    }

    Write-Host ""
    Write-Host "🎉 Done!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Summary:" -ForegroundColor Cyan
    Write-Host "   Version: $version" -ForegroundColor White
    Write-Host "   Channel: $Channel" -ForegroundColor White
    Write-Host "   Agents: $($chatAgents.Count)" -ForegroundColor White
    Write-Host "   Prompts: $($chatPromptFiles.Count)" -ForegroundColor White
    Write-Host "   Instructions: $($chatInstructions.Count)" -ForegroundColor White
    Write-Host ""

    exit 0
    }
}
catch {
    Write-Error "Prepare Extension failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion