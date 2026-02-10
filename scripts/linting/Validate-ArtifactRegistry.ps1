# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Validate-ArtifactRegistry.ps1
#
# Purpose: Validates the AI Artifacts Registry against its schema and the filesystem
# Author: HVE Core Team

#Requires -Version 7.0

<#
.SYNOPSIS
    Validates the AI Artifacts Registry against its schema and the filesystem.

.DESCRIPTION
    Validates the `.github/ai-artifacts-registry.json` file by checking:
    - JSON structure, required fields, and additional-property constraints
    - JSON Schema validation (PowerShell 7.4+ with Test-Json -SchemaFile)
    - Per-artifact required fields (maturity, personas, tags)
    - Maturity enum values and persona reference format
    - Persona ID format and reference validity
    - Artifact file existence on disk
    - Dependency reference validity
    - Orphan file detection (files on disk not in registry)

.PARAMETER RegistryPath
    Path to the registry JSON file. Defaults to `.github/ai-artifacts-registry.json`.

.PARAMETER RepoRoot
    Repository root for resolving artifact file paths. Defaults to script's grandparent.

.PARAMETER WarningsAsErrors
    Treat warnings (orphan files) as errors.

.PARAMETER OutputPath
    Path to write JSON results. Defaults to `logs/registry-validation-results.json`.

.OUTPUTS
    Hashtable with Success bool, Errors array, Warnings array.

.EXAMPLE
    ./Validate-ArtifactRegistry.ps1
    # Validates registry with default paths

.EXAMPLE
    ./Validate-ArtifactRegistry.ps1 -WarningsAsErrors
    # Treats orphan file warnings as errors
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RegistryPath,

    [Parameter()]
    [string]$RepoRoot,

    [Parameter()]
    [switch]$WarningsAsErrors,

    [Parameter()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

# Import CI helpers
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force

#region Validation Functions

function Test-RegistryStructure {
    <#
    .SYNOPSIS
        Validates the registry JSON structure including required fields.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    # JSON parse
    try {
        $content = Get-Content -Path $RegistryPath -Raw
        $registry = $content | ConvertFrom-Json -AsHashtable
    }
    catch {
        $errors.Add("Failed to parse registry JSON: $_")
        return @{ Success = $false; Errors = $errors; Registry = $null }
    }

    # Required top-level fields
    $requiredFields = @('$schema', 'version', 'personas', 'agents', 'prompts', 'instructions', 'skills')
    foreach ($field in $requiredFields) {
        if (-not $registry.ContainsKey($field)) {
            $errors.Add("Missing required field: $field")
        }
    }

    # Version format
    if ($registry.ContainsKey('version') -and $registry['version'] -notmatch '^\d+\.\d+$') {
        $errors.Add("Invalid version format: $($registry['version']). Expected: major.minor")
    }

    # Personas.definitions
    if ($registry.ContainsKey('personas') -and -not $registry['personas'].ContainsKey('definitions')) {
        $errors.Add("Missing required field: personas.definitions")
    }

    # Additional properties - top level
    $allowedTopLevel = @('$schema', 'version', 'personas', 'agents', 'prompts', 'instructions', 'skills')
    foreach ($key in $registry.Keys) {
        if ($key -notin $allowedTopLevel) {
            $errors.Add("Unexpected top-level property: $key")
        }
    }

    # Additional properties - personas
    if ($registry.ContainsKey('personas')) {
        foreach ($key in $registry['personas'].Keys) {
            if ($key -ne 'definitions') {
                $errors.Add("Unexpected property in personas: $key")
            }
        }
    }

    return @{
        Success  = ($errors.Count -eq 0)
        Errors   = $errors
        Registry = $registry
    }
}

function Test-PersonaReferences {
    <#
    .SYNOPSIS
        Validates persona definitions and references in artifact entries.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Registry
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $definedPersonas = @($Registry['personas']['definitions'].Keys)

    # Validate persona definitions
    foreach ($personaId in $definedPersonas) {
        if ($personaId -notmatch '^[a-z][a-z0-9-]*$') {
            $errors.Add("Invalid persona ID format: $personaId")
        }
        $persona = $Registry['personas']['definitions'][$personaId]
        if (-not $persona.ContainsKey('name') -or [string]::IsNullOrEmpty($persona['name'])) {
            $errors.Add("Persona '$personaId' missing 'name' field")
        }
        if (-not $persona.ContainsKey('description') -or [string]::IsNullOrEmpty($persona['description'])) {
            $errors.Add("Persona '$personaId' missing 'description' field")
        }
        # Additional properties on persona definitions
        $allowedPersonaProps = @('name', 'description')
        foreach ($prop in $persona.Keys) {
            if ($prop -notin $allowedPersonaProps) {
                $errors.Add("Persona '$personaId' has unexpected property: $prop")
            }
        }
    }

    # Validate persona references in artifacts
    $sections = @('agents', 'prompts', 'instructions', 'skills')
    foreach ($section in $sections) {
        foreach ($key in $Registry[$section].Keys) {
            $entry = $Registry[$section][$key]
            if ($entry.ContainsKey('personas')) {
                foreach ($personaRef in $entry['personas']) {
                    if ($personaRef -notin $definedPersonas) {
                        $errors.Add("${section}/${key} references undefined persona: $personaRef")
                    }
                }
            }
        }
    }

    return @{ Success = ($errors.Count -eq 0); Errors = $errors }
}

function Test-ArtifactEntries {
    <#
    .SYNOPSIS
        Validates per-artifact required fields, maturity enum, and property constraints.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Registry
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $validMaturity = @('stable', 'preview', 'experimental', 'deprecated')
    $personaPattern = '^[a-z][a-z0-9-]*$'

    $simpleAllowed = @('maturity', 'personas', 'tags')
    $agentAllowed = @('maturity', 'personas', 'tags', 'requires')
    $requiresAllowed = @('agents', 'prompts', 'instructions', 'skills')

    $sectionAllowed = @{
        agents       = $agentAllowed
        prompts      = $simpleAllowed
        instructions = $simpleAllowed
        skills       = $simpleAllowed
    }

    foreach ($section in $sectionAllowed.Keys) {
        if (-not $Registry.ContainsKey($section)) { continue }

        foreach ($key in $Registry[$section].Keys) {
            $entry = $Registry[$section][$key]
            $prefix = "${section}/${key}"

            if ($entry -isnot [hashtable]) {
                $errors.Add("${prefix}: entry must be an object")
                continue
            }

            # Required field: maturity
            if (-not $entry.ContainsKey('maturity')) {
                $errors.Add("${prefix}: missing required field 'maturity'")
            }
            elseif ($entry['maturity'] -notin $validMaturity) {
                $errors.Add("${prefix}: invalid maturity '$($entry['maturity'])'. Must be one of: $($validMaturity -join ', ')")
            }

            # Required field: personas
            if (-not $entry.ContainsKey('personas')) {
                $errors.Add("${prefix}: missing required field 'personas'")
            }
            elseif ($entry['personas'] -isnot [System.Collections.IList]) {
                $errors.Add("${prefix}: 'personas' must be an array")
            }
            else {
                foreach ($p in $entry['personas']) {
                    if ($p -notmatch $personaPattern) {
                        $errors.Add("${prefix}: invalid persona reference format '$p'. Must match: $personaPattern")
                    }
                }
            }

            # Required field: tags
            if (-not $entry.ContainsKey('tags')) {
                $errors.Add("${prefix}: missing required field 'tags'")
            }
            elseif ($entry['tags'] -isnot [System.Collections.IList]) {
                $errors.Add("${prefix}: 'tags' must be an array")
            }

            # No unexpected properties
            $allowed = $sectionAllowed[$section]
            foreach ($prop in $entry.Keys) {
                if ($prop -notin $allowed) {
                    $errors.Add("${prefix}: unexpected property '$prop'")
                }
            }

            # Agent requires block structure
            if ($section -eq 'agents' -and $entry.ContainsKey('requires')) {
                $requires = $entry['requires']
                if ($requires -isnot [hashtable]) {
                    $errors.Add("${prefix}: 'requires' must be an object")
                }
                else {
                    foreach ($reqProp in $requires.Keys) {
                        if ($reqProp -notin $requiresAllowed) {
                            $errors.Add("${prefix}: unexpected property in requires: '$reqProp'")
                        }
                        elseif ($requires[$reqProp] -isnot [System.Collections.IList]) {
                            $errors.Add("${prefix}: requires.$reqProp must be an array")
                        }
                    }
                }
            }
        }
    }

    return @{ Success = ($errors.Count -eq 0); Errors = $errors }
}

function Test-JsonSchemaValidation {
    <#
    .SYNOPSIS
        Validates registry JSON against the schema file using Test-Json when available.
    .DESCRIPTION
        Requires PowerShell 7.4+ for Test-Json -SchemaFile support. Skips gracefully
        on older versions.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,

        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    if (-not (Test-Path $SchemaPath)) {
        $errors.Add("Schema file not found: $SchemaPath")
        return @{ Success = $false; Errors = $errors }
    }

    if ($PSVersionTable.PSVersion -lt [version]'7.4') {
        Write-Verbose "Skipping JSON Schema validation: requires PowerShell 7.4+ (current: $($PSVersionTable.PSVersion))"
        return @{ Success = $true; Errors = $errors }
    }

    try {
        $content = Get-Content -Path $RegistryPath -Raw
        $schemaErrors = $null
        $valid = Test-Json -Json $content -SchemaFile $SchemaPath -ErrorAction SilentlyContinue -ErrorVariable schemaErrors
        if (-not $valid) {
            foreach ($schemaErr in $schemaErrors) {
                $errors.Add("Schema violation: $schemaErr")
            }
            if ($errors.Count -eq 0) {
                $errors.Add("Registry does not conform to JSON Schema")
            }
        }
    }
    catch {
        $errors.Add("JSON Schema validation error: $($_.Exception.Message)")
    }

    return @{ Success = ($errors.Count -eq 0); Errors = $errors }
}

function Get-ArtifactPath {
    <#
    .SYNOPSIS
        Resolves the file path for an artifact based on section and key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Section,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    switch ($Section) {
        'agents' {
            return Join-Path $RepoRoot ".github/agents/$Key.agent.md"
        }
        'prompts' {
            return Join-Path $RepoRoot ".github/prompts/$Key.prompt.md"
        }
        'instructions' {
            return Join-Path $RepoRoot ".github/instructions/$Key.instructions.md"
        }
        'skills' {
            return Join-Path $RepoRoot ".github/skills/$Key/SKILL.md"
        }
        default {
            return $null
        }
    }
}

function Test-ArtifactFileExistence {
    <#
    .SYNOPSIS
        Validates that each artifact key maps to an existing file on disk.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Registry,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $sections = @('agents', 'prompts', 'instructions', 'skills')

    foreach ($section in $sections) {
        foreach ($key in $Registry[$section].Keys) {
            $path = Get-ArtifactPath -Section $section -Key $key -RepoRoot $RepoRoot
            if (-not (Test-Path $path)) {
                $errors.Add("${section}/${key}: File not found at $path")
            }
        }
    }

    return @{ Success = ($errors.Count -eq 0); Errors = $errors }
}

function Test-DependencyReferences {
    <#
    .SYNOPSIS
        Validates that dependency references point to existing registry entries.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Registry
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    # Build reference sets
    $validAgents = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Registry['agents'].Keys))
    $validPrompts = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Registry['prompts'].Keys))
    $validInstructions = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Registry['instructions'].Keys))
    $validSkills = [System.Collections.Generic.HashSet[string]]::new([string[]]@($Registry['skills'].Keys))

    # Only agents have requires blocks (by design)
    foreach ($agentKey in $Registry['agents'].Keys) {
        $agent = $Registry['agents'][$agentKey]
        if (-not $agent.ContainsKey('requires')) { continue }

        $requires = $agent['requires']

        if ($requires.ContainsKey('agents')) {
            foreach ($ref in $requires['agents']) {
                if (-not $validAgents.Contains($ref)) {
                    $errors.Add("agents/${agentKey} requires.agents references unknown agent: $ref")
                }
            }
        }

        if ($requires.ContainsKey('prompts')) {
            foreach ($ref in $requires['prompts']) {
                if (-not $validPrompts.Contains($ref)) {
                    $errors.Add("agents/${agentKey} requires.prompts references unknown prompt: $ref")
                }
            }
        }

        if ($requires.ContainsKey('instructions')) {
            foreach ($ref in $requires['instructions']) {
                if (-not $validInstructions.Contains($ref)) {
                    $errors.Add("agents/${agentKey} requires.instructions references unknown instruction: $ref")
                }
            }
        }

        if ($requires.ContainsKey('skills')) {
            foreach ($ref in $requires['skills']) {
                if (-not $validSkills.Contains($ref)) {
                    $errors.Add("agents/${agentKey} requires.skills references unknown skill: $ref")
                }
            }
        }
    }

    # Detect circular agent dependencies (warning only)
    $circularChains = Find-CircularAgentDependencies -Registry $Registry
    foreach ($chain in $circularChains) {
        $warnings.Add("Circular agent dependency detected: $($chain -join ' -> ')")
    }

    return @{ Success = ($errors.Count -eq 0); Errors = $errors; Warnings = $warnings }
}

function Find-CircularAgentDependencies {
    <#
    .SYNOPSIS
        Detects circular dependencies in agent requires.agents chains.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[string[]]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Registry
    )

    $chains = [System.Collections.Generic.List[string[]]]::new()
    $globalVisited = @{}

    foreach ($agent in $Registry['agents'].Keys) {
        $path = [System.Collections.Generic.List[string]]::new()
        $localVisited = @{}
        Find-CycleFromAgent -Registry $Registry -Agent $agent -Path $path -LocalVisited $localVisited -GlobalVisited $globalVisited -Chains $chains
    }

    return $chains
}

function Find-CycleFromAgent {
    param(
        [hashtable]$Registry,
        [string]$Agent,
        [System.Collections.Generic.List[string]]$Path,
        [hashtable]$LocalVisited,
        [hashtable]$GlobalVisited,
        [System.Collections.Generic.List[string[]]]$Chains
    )

    if ($LocalVisited.ContainsKey($Agent)) {
        $cycleStart = $Path.IndexOf($Agent)
        if ($cycleStart -ge 0) {
            $cycle = @($Path[$cycleStart..($Path.Count - 1)]) + @($Agent)
            $cycleKey = ($cycle | Sort-Object) -join ','
            if (-not $GlobalVisited.ContainsKey($cycleKey)) {
                $GlobalVisited[$cycleKey] = $true
                $Chains.Add($cycle)
            }
        }
        return
    }

    $LocalVisited[$Agent] = $true
    $Path.Add($Agent)

    $entry = $Registry['agents'][$Agent]
    if ($entry -and $entry.ContainsKey('requires') -and $entry['requires'].ContainsKey('agents')) {
        foreach ($dep in $entry['requires']['agents']) {
            if ($Registry['agents'].ContainsKey($dep)) {
                Find-CycleFromAgent -Registry $Registry -Agent $dep -Path $Path -LocalVisited $LocalVisited -GlobalVisited $GlobalVisited -Chains $Chains
            }
        }
    }

    $Path.RemoveAt($Path.Count - 1)
    $LocalVisited.Remove($Agent)
}

function Find-OrphanArtifacts {
    <#
    .SYNOPSIS
        Detects artifact files on disk that are not registered in the registry.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Registry,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $warnings = [System.Collections.Generic.List[string]]::new()

    # Scan agents
    $agentsDir = Join-Path $RepoRoot '.github/agents'
    if (Test-Path $agentsDir) {
        $agentFiles = Get-ChildItem -Path $agentsDir -Filter '*.agent.md' -File -ErrorAction SilentlyContinue
        foreach ($file in $agentFiles) {
            $key = $file.BaseName -replace '\.agent$', ''
            if (-not $Registry['agents'].ContainsKey($key)) {
                $warnings.Add("Orphan agent file not in registry: $($file.FullName)")
            }
        }
    }

    # Scan prompts
    $promptsDir = Join-Path $RepoRoot '.github/prompts'
    if (Test-Path $promptsDir) {
        $promptFiles = Get-ChildItem -Path $promptsDir -Filter '*.prompt.md' -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $promptFiles) {
            $key = $file.BaseName -replace '\.prompt$', ''
            if (-not $Registry['prompts'].ContainsKey($key)) {
                $warnings.Add("Orphan prompt file not in registry: $($file.FullName)")
            }
        }
    }

    # Scan instructions (including subdirectories, excluding repo-specific hve-core/ folder)
    $instructionsDir = Join-Path $RepoRoot '.github/instructions'
    if (Test-Path $instructionsDir) {
        $instructionFiles = Get-ChildItem -Path $instructionsDir -Filter '*.instructions.md' -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $instructionFiles) {
            $relativePath = [System.IO.Path]::GetRelativePath($instructionsDir, $file.FullName) -replace '\\', '/'
            # Skip repo-specific instructions not intended for distribution
            if ($relativePath -like 'hve-core/*') { continue }
            $key = $relativePath -replace '\.instructions\.md$', ''
            if (-not $Registry['instructions'].ContainsKey($key)) {
                $warnings.Add("Orphan instruction file not in registry: $($file.FullName)")
            }
        }
    }

    # Scan skills
    $skillsDir = Join-Path $RepoRoot '.github/skills'
    if (Test-Path $skillsDir) {
        $skillDirs = Get-ChildItem -Path $skillsDir -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $skillDirs) {
            $skillFile = Join-Path $dir.FullName 'SKILL.md'
            if (Test-Path $skillFile) {
                $key = $dir.Name
                if (-not $Registry['skills'].ContainsKey($key)) {
                    $warnings.Add("Orphan skill directory not in registry: $($dir.FullName)")
                }
            }
        }
    }

    return @{ Warnings = $warnings }
}

function Test-CollectionManifests {
    <#
    .SYNOPSIS
        Validates collection manifest files against their schema and registry.
    .DESCRIPTION
        Checks all collection manifest files in extension/collections/ for:
        - Valid JSON structure
        - Valid maturity enum values
        - Persona references matching registry definitions
        - JSON Schema validation (PowerShell 7.4+)
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Registry,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $collectionsDir = Join-Path $RepoRoot 'extension/collections'
    if (-not (Test-Path $collectionsDir)) {
        return @{ Success = $true; Errors = $errors; Warnings = $warnings }
    }

    $validMaturity = @('stable', 'preview', 'experimental', 'deprecated')
    $definedPersonas = @()
    if ($Registry.ContainsKey('personas') -and $Registry['personas'].ContainsKey('definitions')) {
        $definedPersonas = @($Registry['personas']['definitions'].Keys)
    }

    $collectionFiles = Get-ChildItem -Path $collectionsDir -Filter '*.collection.json' -File -ErrorAction SilentlyContinue

    # JSON Schema validation for collection manifests
    $collectionSchemaPath = Join-Path $RepoRoot 'scripts/linting/schemas/collection.schema.json'

    foreach ($file in $collectionFiles) {
        $prefix = "collection/$($file.BaseName -replace '\.collection$', '')"

        try {
            $content = Get-Content -Path $file.FullName -Raw
            $manifest = $content | ConvertFrom-Json -AsHashtable
        }
        catch {
            $errors.Add("${prefix}: Failed to parse JSON: $_")
            continue
        }

        # Validate maturity value if present
        if ($manifest.ContainsKey('maturity')) {
            if ($manifest['maturity'] -notin $validMaturity) {
                $errors.Add("${prefix}: invalid maturity '$($manifest['maturity'])'. Must be one of: $($validMaturity -join ', ')")
            }
        }

        # Validate persona references
        if ($manifest.ContainsKey('personas')) {
            foreach ($persona in $manifest['personas']) {
                if ($definedPersonas.Count -gt 0 -and $persona -notin $definedPersonas -and $persona -ne 'hve-core-all') {
                    $warnings.Add("${prefix}: references persona '$persona' not defined in registry")
                }
            }
        }

        # Warn about deprecated collections that still exist in the build directory
        if ($manifest.ContainsKey('maturity') -and $manifest['maturity'] -eq 'deprecated') {
            $warnings.Add("${prefix}: collection is deprecated and will be excluded from all builds")
        }

        # JSON Schema validation (PowerShell 7.4+)
        if ((Test-Path $collectionSchemaPath) -and $PSVersionTable.PSVersion -ge [version]'7.4') {
            try {
                $schemaErrors = $null
                $valid = Test-Json -Json $content -SchemaFile $collectionSchemaPath -ErrorAction SilentlyContinue -ErrorVariable schemaErrors
                if (-not $valid) {
                    foreach ($schemaErr in $schemaErrors) {
                        $errors.Add("${prefix}: schema violation: $schemaErr")
                    }
                }
            }
            catch {
                $errors.Add("${prefix}: schema validation error: $($_.Exception.Message)")
            }
        }
    }

    return @{ Success = ($errors.Count -eq 0); Errors = $errors; Warnings = $warnings }
}

#endregion Validation Functions

#region Output Functions

function Write-RegistryValidationOutput {
    <#
    .SYNOPSIS
        Writes validation results to console with formatting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Result,

        [Parameter(Mandatory)]
        [string]$RegistryPath
    )

    Write-Host "`n🔍 Registry Validation Results" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   Registry: $RegistryPath"

    if ($Result.Errors.Count -gt 0) {
        Write-Host "`n❌ Errors ($($Result.Errors.Count)):" -ForegroundColor Red
        foreach ($errorItem in $Result.Errors) {
            Write-Host "   • $errorItem" -ForegroundColor Red
        }
    }

    if ($Result.Warnings.Count -gt 0) {
        Write-Host "`n⚠️ Warnings ($($Result.Warnings.Count)):" -ForegroundColor Yellow
        foreach ($warningItem in $Result.Warnings) {
            Write-Host "   • $warningItem" -ForegroundColor Yellow
        }
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Cyan
    $errorColor = if ($Result.Errors.Count -gt 0) { 'Red' } else { 'Green' }
    $warnColor = if ($Result.Warnings.Count -gt 0) { 'Yellow' } else { 'Green' }
    Write-Host "   Errors: $($Result.Errors.Count)" -ForegroundColor $errorColor
    Write-Host "   Warnings: $($Result.Warnings.Count)" -ForegroundColor $warnColor

    if ($Result.ArtifactCounts) {
        Write-Host "   Agents: $($Result.ArtifactCounts.Agents)"
        Write-Host "   Prompts: $($Result.ArtifactCounts.Prompts)"
        Write-Host "   Instructions: $($Result.ArtifactCounts.Instructions)"
        Write-Host "   Skills: $($Result.ArtifactCounts.Skills)"
    }
}

function Export-RegistryValidationResults {
    <#
    .SYNOPSIS
        Exports validation results to JSON file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Result,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $exportData = @{
        timestamp      = (Get-Date -Format 'o')
        success        = $Result.Success
        errors         = $Result.Errors
        warnings       = $Result.Warnings
        artifactCounts = $Result.ArtifactCounts
    }

    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding utf8
}

#endregion Output Functions

#region Main Execution

try {
    if ($MyInvocation.InvocationName -ne '.') {
        # Resolve paths - script lives at scripts/linting/, so grandparent is repo root
        if (-not $RepoRoot) {
            $RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
        }

        if (-not $RegistryPath) {
            $RegistryPath = Join-Path $RepoRoot '.github/ai-artifacts-registry.json'
        }

        if (-not $OutputPath) {
            $OutputPath = Join-Path $RepoRoot 'logs/registry-validation-results.json'
        }

        Write-Host "🔍 Validating AI Artifacts Registry..." -ForegroundColor Cyan

        # Validate file exists
        if (-not (Test-Path $RegistryPath)) {
            throw "Registry file not found: $RegistryPath"
        }

        # Run validations
        $allErrors = [System.Collections.Generic.List[string]]::new()
        $allWarnings = [System.Collections.Generic.List[string]]::new()

        # Step 1: Structure validation
        $structureResult = Test-RegistryStructure -RegistryPath $RegistryPath
        $allErrors.AddRange($structureResult.Errors)

        if (-not $structureResult.Success) {
            # Cannot continue without valid structure
            $result = @{
                Success        = $false
                Errors         = $allErrors
                Warnings       = $allWarnings
                ArtifactCounts = $null
            }
        }
        else {
            $registry = $structureResult.Registry

            # Step 2: Persona references
            $personaResult = Test-PersonaReferences -Registry $registry
            $allErrors.AddRange($personaResult.Errors)

            # Step 3: Artifact entry validation (maturity, personas, tags, additionalProperties)
            $entryResult = Test-ArtifactEntries -Registry $registry
            $allErrors.AddRange($entryResult.Errors)

            # Step 4: JSON Schema validation (PowerShell 7.4+)
            $schemaPath = Join-Path $PSScriptRoot 'schemas/ai-artifacts-registry.schema.json'
            $schemaResult = Test-JsonSchemaValidation -RegistryPath $RegistryPath -SchemaPath $schemaPath
            $allErrors.AddRange($schemaResult.Errors)

            # Step 5: File existence
            $fileResult = Test-ArtifactFileExistence -Registry $registry -RepoRoot $RepoRoot
            $allErrors.AddRange($fileResult.Errors)

            # Step 6: Dependency references
            $depResult = Test-DependencyReferences -Registry $registry
            $allErrors.AddRange($depResult.Errors)
            $allWarnings.AddRange($depResult.Warnings)

            # Step 7: Orphan detection
            $orphanResult = Find-OrphanArtifacts -Registry $registry -RepoRoot $RepoRoot
            $allWarnings.AddRange($orphanResult.Warnings)

            # Step 8: Collection manifest validation
            $collectionResult = Test-CollectionManifests -Registry $registry -RepoRoot $RepoRoot
            $allErrors.AddRange($collectionResult.Errors)
            $allWarnings.AddRange($collectionResult.Warnings)

            # Build result
            $result = @{
                Success        = ($allErrors.Count -eq 0)
                Errors         = $allErrors
                Warnings       = $allWarnings
                ArtifactCounts = @{
                    Agents       = $registry['agents'].Count
                    Prompts      = $registry['prompts'].Count
                    Instructions = $registry['instructions'].Count
                    Skills       = $registry['skills'].Count
                }
            }
        }

        # Output
        Write-RegistryValidationOutput -Result $result -RegistryPath $RegistryPath

        # CI annotations
        if (Test-CIEnvironment) {
            foreach ($errItem in $result.Errors) {
                Write-CIAnnotation -Message $errItem -Level Error -File $RegistryPath
            }
            foreach ($warnItem in $result.Warnings) {
                Write-CIAnnotation -Message $warnItem -Level Warning -File $RegistryPath
            }
        }

        # Export results
        Export-RegistryValidationResults -Result $result -OutputPath $OutputPath

        # Exit code
        $exitCode = 0
        if ($result.Errors.Count -gt 0) {
            $exitCode = 1
        }
        elseif ($WarningsAsErrors -and $result.Warnings.Count -gt 0) {
            $exitCode = 1
        }

        if ($exitCode -eq 0) {
            Write-Host "`n✅ Registry validation passed!" -ForegroundColor Green
        }
        else {
            Write-Host "`n❌ Registry validation failed!" -ForegroundColor Red
        }

        exit $exitCode
    }
}
catch {
    Write-Error -ErrorAction Continue "Registry validation failed: $($_.Exception.Message)"
    if (Test-CIEnvironment) {
        Write-CIAnnotation -Message "Registry validation failed: $($_.Exception.Message)" -Level Error
    }
    exit 1
}

#endregion
