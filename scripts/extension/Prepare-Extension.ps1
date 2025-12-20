#!/usr/bin/env pwsh
#Requires -Modules PowerShell-Yaml

<#
.SYNOPSIS
    Prepares the HVE Core VS Code extension for packaging.

.DESCRIPTION
    This script prepares the VS Code extension by:
    - Auto-discovering chat agents, chatmodes, prompts, and instruction files
    - Updating package.json with discovered components
    - Updating changelog if provided
    
    The package.json version is not modified.

.PARAMETER ChangelogPath
    Optional. Path to a changelog file to include in the package.

.PARAMETER DryRun
    Optional. If specified, shows what would be done without making changes.

.EXAMPLE
    ./Prepare-Extension.ps1
    # Prepares using existing version from package.json

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
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Determine script and repo paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Get-Item "$ScriptDir/../..").FullName
$ExtensionDir = Join-Path $RepoRoot "extension"
$GitHubDir = Join-Path $RepoRoot ".github"
$PackageJsonPath = Join-Path $ExtensionDir "package.json"

Write-Host "📦 HVE Core Extension Preparer" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
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

# Discover chat agents
Write-Host ""
Write-Host "🔍 Discovering chat agents..." -ForegroundColor Yellow
$agentsDir = Join-Path $GitHubDir "agents"
$chatAgents = @()

if (Test-Path $agentsDir) {
    $agentFiles = Get-ChildItem -Path $agentsDir -Filter "*.agent.md" | Sort-Object Name
    
    foreach ($agentFile in $agentFiles) {
        # Extract agent name from filename (e.g., hve-core-installer.agent.md -> hve-core-installer)
        $agentName = $agentFile.BaseName -replace '\.agent$', ''
        
        # Read the file to extract description from YAML frontmatter
        $content = Get-Content -Path $agentFile.FullName -Raw
        $description = ""
        
        # Extract YAML frontmatter and parse with PowerShell-Yaml
        if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $yamlContent = $Matches[1]
            try {
                $data = ConvertFrom-Yaml -Yaml $yamlContent
                if ($data.ContainsKey('description')) {
                    $description = $data.description
                }
            } catch {
                Write-Warning "Failed to parse YAML frontmatter in $($agentFile.Name): $_"
            }
        }
        
        # Fallback description if not found in frontmatter
        if (-not $description) {
            $description = "AI agent for $agentName"
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

# Discover chatmodes
Write-Host ""
Write-Host "🔍 Discovering chatmodes..." -ForegroundColor Yellow
$chatmodesDir = Join-Path $GitHubDir "chatmodes"
$chatmodes = @()

if (Test-Path $chatmodesDir) {
    $chatmodeFiles = Get-ChildItem -Path $chatmodesDir -Filter "*.chatmode.md" | Sort-Object Name
    
    foreach ($chatmodeFile in $chatmodeFiles) {
        # Extract chatmode name from filename (e.g., task-planner.chatmode.md -> task-planner)
        $chatmodeName = $chatmodeFile.BaseName -replace '\.chatmode$', ''
        
        # Read the file to extract description from YAML frontmatter
        $content = Get-Content -Path $chatmodeFile.FullName -Raw
        $description = ""
        
        # Extract YAML frontmatter and parse with PowerShell-Yaml
        if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $yamlContent = $Matches[1]
            try {
                $data = ConvertFrom-Yaml -Yaml $yamlContent
                if ($data.ContainsKey('description')) {
                    $description = $data.description
                }
            } catch {
                Write-Warning "Failed to parse YAML frontmatter in $($chatmodeFile.Name): $_"
            }
        }
        
        # Fallback description if not found in frontmatter
        if (-not $description) {
            $displayName = ($chatmodeName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }
            $description = "Chatmode for $displayName"
        }
        
        $chatmode = [PSCustomObject]@{
            name        = $chatmodeName
            path        = "./.github/chatmodes/$($chatmodeFile.Name)"
            description = $description
        }
        
        $chatmodes += $chatmode
        Write-Host "   ✅ $chatmodeName" -ForegroundColor Green
    }
} else {
    Write-Warning "Chatmodes directory not found: $chatmodesDir"
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
        
        # Read the file to extract description from YAML frontmatter
        $content = Get-Content -Path $promptFile.FullName -Raw
        $description = ""
        
        # Extract YAML frontmatter and parse with PowerShell-Yaml
        if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $yamlContent = $Matches[1]
            try {
                $data = ConvertFrom-Yaml -Yaml $yamlContent
                if ($data.ContainsKey('description')) {
                    $description = $data.description
                }
            } catch {
                Write-Warning "Failed to parse YAML frontmatter in $($promptFile.Name): $_"
            }
        }
        
        # Fallback description if not found in frontmatter
        if (-not $description) {
            $displayName = ($promptName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }
            $description = "Prompt for $displayName"
        }
        
        # Calculate relative path from .github
        $relativePath = $promptFile.FullName.Substring($GitHubDir.Length + 1) -replace '\\', '/'
        
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
        
        # Read the file to extract description from YAML frontmatter
        $content = Get-Content -Path $instrFile.FullName -Raw
        $description = ""
        
        # Extract YAML frontmatter and parse with PowerShell-Yaml
        if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $yamlContent = $Matches[1]
            try {
                $data = ConvertFrom-Yaml -Yaml $yamlContent
                if ($data.ContainsKey('description')) {
                    $description = $data.description
                }
            } catch {
                Write-Warning "Failed to parse YAML frontmatter in $($instrFile.Name): $_"
            }
        }
        
        # Fallback to generated description if not found in frontmatter
        if (-not $description) {
            $displayName = ($baseName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }
            $description = "Instructions for $displayName"
        }
        
        # Calculate relative path from .github
        $relativePath = $instrFile.FullName.Substring($GitHubDir.Length + 1) -replace '\\', '/'
        
        $instruction = [PSCustomObject]@{
            name        = $instrName
            path        = "./.github/$relativePath"
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

# Combine agents and chatmodes into chatAgents (VS Code treats chatmodes as chatAgents)
$allChatAgents = $chatAgents + $chatmodes

# Update chatAgents
$packageJson.contributes.chatAgents = $allChatAgents
Write-Host "   Updated chatAgents: $($allChatAgents.Count) items ($($chatAgents.Count) agents + $($chatmodes.Count) chatmodes)" -ForegroundColor Green

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
if ($ChangelogPath -and $ChangelogPath -ne "") {
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
Write-Host "   Chat Agents: $($chatAgents.Count)" -ForegroundColor White
Write-Host "   Chatmodes: $($chatmodes.Count)" -ForegroundColor White
Write-Host "   Prompts: $($chatPromptFiles.Count)" -ForegroundColor White
Write-Host "   Instructions: $($chatInstructions.Count)" -ForegroundColor White
Write-Host ""

exit 0
