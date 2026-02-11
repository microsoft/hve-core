#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

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

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

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

function New-PrepareResult {
    <#
    .SYNOPSIS
        Creates a standardized result object for extension preparation operations.
    .DESCRIPTION
        Factory function that creates a hashtable with consistent properties
        for reporting preparation operation outcomes.
    .PARAMETER Success
        Indicates whether the operation completed successfully.
    .PARAMETER Version
        The version string from package.json.
    .PARAMETER AgentCount
        Number of agents discovered and included.
    .PARAMETER PromptCount
        Number of prompts discovered and included.
    .PARAMETER InstructionCount
        Number of instructions discovered and included.
    .PARAMETER ErrorMessage
        Error description when Success is false.
    .OUTPUTS
        Hashtable with Success, Version, AgentCount, PromptCount,
        InstructionCount, and ErrorMessage properties.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Success,

        [Parameter(Mandatory = $false)]
        [string]$Version = "",

        [Parameter(Mandatory = $false)]
        [int]$AgentCount = 0,

        [Parameter(Mandatory = $false)]
        [int]$PromptCount = 0,

        [Parameter(Mandatory = $false)]
        [int]$InstructionCount = 0,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = ""
    )

    return @{
        Success          = $Success
        Version          = $Version
        AgentCount       = $AgentCount
        PromptCount      = $PromptCount
        InstructionCount = $InstructionCount
        ErrorMessage     = $ErrorMessage
    }
}

function Invoke-PrepareExtension {
    <#
    .SYNOPSIS
        Orchestrates VS Code extension preparation with full error handling.
    .DESCRIPTION
        Executes the complete preparation workflow: validates paths, discovers
        agents/prompts/instructions, updates package.json, and handles changelog.
        Returns a result object instead of using exit codes.
    .PARAMETER ExtensionDirectory
        Absolute path to the extension directory containing package.json.
    .PARAMETER RepoRoot
        Absolute path to the repository root directory.
    .PARAMETER Channel
        Release channel controlling maturity filter ('Stable' or 'PreRelease').
    .PARAMETER ChangelogPath
        Optional path to changelog file to include.
    .PARAMETER DryRun
        When specified, shows what would be done without making changes.
    .OUTPUTS
        Hashtable with Success, Version, AgentCount, PromptCount,
        InstructionCount, and ErrorMessage properties.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExtensionDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'Stable',

        [Parameter(Mandatory = $false)]
        [string]$ChangelogPath = "",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    # Derive paths
    $GitHubDir = Join-Path $RepoRoot ".github"
    $PackageJsonPath = Join-Path $ExtensionDirectory "package.json"

    # Validate required paths exist
    $pathValidation = Test-PathsExist -ExtensionDir $ExtensionDirectory `
        -PackageJsonPath $PackageJsonPath `
        -GitHubDir $GitHubDir
    if (-not $pathValidation.IsValid) {
        $missingPaths = $pathValidation.MissingPaths -join ', '
        return New-PrepareResult -Success $false -ErrorMessage "Required paths not found: $missingPaths"
    }

    # Read and parse package.json
    try {
        $packageJsonContent = Get-Content -Path $PackageJsonPath -Raw
        $packageJson = $packageJsonContent | ConvertFrom-Json
    }
    catch {
        return New-PrepareResult -Success $false -ErrorMessage "Failed to parse package.json at '$PackageJsonPath'. Check the file for JSON syntax errors. Underlying error: $($_.Exception.Message)"
    }

    # Validate version field
    if (-not $packageJson.PSObject.Properties['version']) {
        return New-PrepareResult -Success $false -ErrorMessage "package.json does not contain a 'version' field"
    }
    $version = $packageJson.version
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        return New-PrepareResult -Success $false -ErrorMessage "Invalid version format in package.json: $version"
    }

    # Get allowed maturities for channel
    $allowedMaturities = Get-AllowedMaturities -Channel $Channel

    Write-Host "`n=== Prepare Extension ===" -ForegroundColor Cyan
    Write-Host "Extension Directory: $ExtensionDirectory"
    Write-Host "Repository Root: $RepoRoot"
    Write-Host "Channel: $Channel"
    Write-Host "Allowed Maturities: $($allowedMaturities -join ', ')"
    Write-Host "Version: $version"
    if ($DryRun) {
        Write-Host "[DRY RUN] No changes will be made" -ForegroundColor Yellow
    }

    # Discover agents
    $agentsDir = Join-Path $GitHubDir "agents"
    $agentResult = Get-DiscoveredAgents -AgentsDir $agentsDir -AllowedMaturities $allowedMaturities -ExcludedAgents @()
    $chatAgents = $agentResult.Agents
    $excludedAgents = $agentResult.Skipped

    Write-Host "`n--- Chat Agents ---" -ForegroundColor Green
    Write-Host "Found $($chatAgents.Count) agent(s) matching criteria"
    if ($excludedAgents.Count -gt 0) {
        Write-Host "Excluded $($excludedAgents.Count) agent(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Discover prompts
    $promptsDir = Join-Path $GitHubDir "prompts"
    $promptResult = Get-DiscoveredPrompts -PromptsDir $promptsDir -GitHubDir $GitHubDir -AllowedMaturities $allowedMaturities
    $chatPrompts = $promptResult.Prompts
    $excludedPrompts = $promptResult.Skipped

    Write-Host "`n--- Chat Prompts ---" -ForegroundColor Green
    Write-Host "Found $($chatPrompts.Count) prompt(s) matching criteria"
    if ($excludedPrompts.Count -gt 0) {
        Write-Host "Excluded $($excludedPrompts.Count) prompt(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Discover instructions
    $instructionsDir = Join-Path $GitHubDir "instructions"
    $instructionResult = Get-DiscoveredInstructions -InstructionsDir $instructionsDir -GitHubDir $GitHubDir -AllowedMaturities $allowedMaturities
    $chatInstructions = $instructionResult.Instructions
    $excludedInstructions = $instructionResult.Skipped

    Write-Host "`n--- Chat Instructions ---" -ForegroundColor Green
    Write-Host "Found $($chatInstructions.Count) instruction(s) matching criteria"
    if ($excludedInstructions.Count -gt 0) {
        Write-Host "Excluded $($excludedInstructions.Count) instruction(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Update package.json
    $packageJson = Update-PackageJsonContributes -PackageJson $packageJson `
        -ChatAgents $chatAgents `
        -ChatPromptFiles $chatPrompts `
        -ChatInstructions $chatInstructions

    # Write updated package.json
    if (-not $DryRun) {
        $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $PackageJsonPath -Encoding UTF8NoBOM
        Write-Host "`nUpdated package.json with discovered artifacts" -ForegroundColor Green
    }
    else {
        Write-Host "`n[DRY RUN] Would update package.json with discovered artifacts" -ForegroundColor Yellow
    }

    # Handle changelog
    if ($ChangelogPath -and (Test-Path $ChangelogPath)) {
        $destChangelog = Join-Path $ExtensionDirectory "CHANGELOG.md"
        if (-not $DryRun) {
            Copy-Item -Path $ChangelogPath -Destination $destChangelog -Force
            Write-Host "Copied changelog to extension directory" -ForegroundColor Green
        }
        else {
            Write-Host "[DRY RUN] Would copy changelog to extension directory" -ForegroundColor Yellow
        }
    }
    elseif ($ChangelogPath) {
        Write-Warning "Changelog path specified but file not found: $ChangelogPath"
    }

    Write-Host "`n=== Preparation Complete ===" -ForegroundColor Cyan

    return New-PrepareResult -Success $true `
        -Version $version `
        -AgentCount $chatAgents.Count `
        -PromptCount $chatPrompts.Count `
        -InstructionCount $chatInstructions.Count
}

#endregion Pure Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        # Verify PowerShell-Yaml module is available
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            throw "Required module 'PowerShell-Yaml' is not installed."
        }
        Import-Module PowerShell-Yaml -ErrorAction Stop

        # Resolve paths using $MyInvocation (must stay in entry point)
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName
        $ExtensionDir = Join-Path $RepoRoot "extension"

        # Resolve changelog path if provided
        $resolvedChangelogPath = ""
        if ($ChangelogPath) {
            $resolvedChangelogPath = if ([System.IO.Path]::IsPathRooted($ChangelogPath)) {
                $ChangelogPath
            }
            else {
                Join-Path $RepoRoot $ChangelogPath
            }
        }

        Write-Host "📦 HVE Core Extension Preparer" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
        Write-Host "   Channel: $Channel" -ForegroundColor Cyan
        Write-Host ""

        # Call orchestration function
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $ExtensionDir `
            -RepoRoot $RepoRoot `
            -Channel $Channel `
            -ChangelogPath $resolvedChangelogPath `
            -DryRun:$DryRun

        if (-not $result.Success) {
            throw $result.ErrorMessage
        }

        Write-Host ""
        Write-Host "🎉 Done!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📊 Summary:" -ForegroundColor Cyan
        Write-Host "  Agents: $($result.AgentCount)"
        Write-Host "  Prompts: $($result.PromptCount)"
        Write-Host "  Instructions: $($result.InstructionCount)"
        Write-Host "  Version: $($result.Version)"

        exit 0
    }
    catch {
        Write-Error "Prepare Extension failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
