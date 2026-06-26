#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Promotes an agent between maturity tiers, rewriting its picker name suffix and incoming references.
.DESCRIPTION
    Rewrites the target agent's name frontmatter and every incoming reference
    (agents: list entries and handoffs.agent: values) across all .github/agents/**/*.agent.md
    files to align with the picker-name suffix for the target maturity. Rewrites
    are computed against the pre-rename name and applied in a single pass.

    Also synchronizes the target agent's 'maturity:' field in the central
    collections manifest (collections/core-manifest.yml) so the manifest does not
    retain a stale maturity tier after the picker name is rewritten. The manifest
    update is keyed off the agent's manifest 'path:' entry and is skipped when the
    manifest, the agent entry, or the maturity value cannot be located.

    Supports -WhatIf and -Confirm. Body prose mentions of the previous suffixed
    name trigger warnings unless -RewriteProse is supplied, in which case the
    prose mentions are rewritten as well.
.PARAMETER AgentPath
    Path to the target agent file (relative to the current directory or absolute).
.PARAMETER TargetMaturity
    Target maturity tier: experimental, preview, or stable.
.PARAMETER RewriteProse
    Rewrite prose mentions of the previous suffixed name in body text. When omitted,
    prose mentions only produce warnings.
.PARAMETER ManifestPath
    Path to the central collections manifest. Defaults to collections/core-manifest.yml
    under RepoRoot. When the manifest is absent the maturity sync is skipped with a warning.
.PARAMETER DryRun
    Reports planned changes without modifying files. Equivalent to -WhatIf.
.PARAMETER RepoRoot
    Repository root used to scope reference scanning. Defaults to two directories
    above the script.
.EXAMPLE
    ./Promote-Agent.ps1 -AgentPath .github/agents/security/security-planner.agent.md -TargetMaturity preview
.EXAMPLE
    npm run promote:agent -- -AgentPath .github/agents/security/security-planner.agent.md -TargetMaturity preview -WhatIf
.NOTES
    Runs via: npm run promote:agent -- -AgentPath <path> -TargetMaturity <maturity>
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$AgentPath,

    [Parameter()]
    [ValidateSet('experimental', 'preview', 'stable')]
    [string]$TargetMaturity,

    [Parameter()]
    [switch]$RewriteProse,

    [Parameter()]
    [string]$ManifestPath,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/CollectionHelpers.psm1') -Force

#region Functions

function Get-AgentBaseName {
    <#
    .SYNOPSIS
        Strips a trailing maturity suffix from an agent picker name.
    .DESCRIPTION
        Removes ' (exp)' or ' (pre)' from the end of an agent name.
        Returns the trimmed input unchanged when no recognized suffix is present.
    .PARAMETER Name
        Picker name potentially ending with a maturity suffix.
    .OUTPUTS
        [string] Base name with any maturity suffix removed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    return ($Name -replace '\s*\((?:exp|pre)\)\s*$', '').Trim()
}

function Get-AgentReferenceFile {
    <#
    .SYNOPSIS
        Returns all agent files under .github/agents that may reference other agents.
    .PARAMETER RepoRoot
        Repository root containing the .github/agents tree.
    .OUTPUTS
        [System.IO.FileInfo[]] Collection of agent files.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $agentsDir = Join-Path $RepoRoot '.github/agents'
    if (-not (Test-Path -LiteralPath $agentsDir)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $agentsDir -Filter '*.agent.md' -Recurse -File)
}

function Update-AgentNameReference {
    <#
    .SYNOPSIS
        Rewrites agent name references inside agent file content.
    .DESCRIPTION
        Operates only inside the YAML frontmatter region for structural references
        (name field, list entries, handoffs.agent values) and optionally over the
        body for prose mentions. Preserves original line endings by splicing the
        transformed frontmatter into the original content.
    .PARAMETER Content
        Full file content to transform.
    .PARAMETER OldName
        Current picker name to replace.
    .PARAMETER NewName
        Replacement picker name.
    .PARAMETER IsTarget
        When true, also rewrites the frontmatter name field.
    .PARAMETER RewriteProse
        When true, rewrites body prose mentions of OldName.
    .OUTPUTS
        [hashtable] With Content, Changes, and ProseMentions keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OldName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$NewName,

        [Parameter()]
        [switch]$IsTarget,

        [Parameter()]
        [switch]$RewriteProse
    )

    $changes = 0
    $proseMentions = 0

    $fmMatch = [regex]::Match($Content, '(?s)^(---\s*\r?\n)(.*?)(\r?\n---\s*\r?\n)')
    if (-not $fmMatch.Success) {
        return @{ Content = $Content; Changes = 0; ProseMentions = 0 }
    }

    $preFm = $fmMatch.Groups[1].Value
    $fmContent = $fmMatch.Groups[2].Value
    $postFm = $fmMatch.Groups[3].Value
    $bodyStart = $fmMatch.Index + $fmMatch.Length
    $body = if ($bodyStart -lt $Content.Length) { $Content.Substring($bodyStart) } else { '' }

    $escapedOld = [regex]::Escape($OldName)
    $updatedFm = $fmContent

    $patterns = @()
    if ($IsTarget) {
        $patterns += "(?m)^(?<prefix>\s*name:\s*)(?<open>['""]?)$escapedOld(?<close>['""]?)\s*$"
    }
    $patterns += "(?m)^(?<prefix>\s*-\s*)(?<open>['""]?)$escapedOld(?<close>['""]?)\s*$"
    $patterns += "(?m)^(?<prefix>\s*agent:\s*)(?<open>['""]?)$escapedOld(?<close>['""]?)\s*$"

    $replacementName = $NewName
    foreach ($pattern in $patterns) {
        $matchList = [regex]::Matches($updatedFm, $pattern)
        if ($matchList.Count -eq 0) {
            continue
        }
        $changes += $matchList.Count
        $updatedFm = [regex]::Replace($updatedFm, $pattern, {
                param($m)
                "$($m.Groups['prefix'].Value)$($m.Groups['open'].Value)$replacementName$($m.Groups['close'].Value)"
            })
    }

    $updatedBody = $body
    if ($body.Length -gt 0) {
        $bodyMatchList = [regex]::Matches($body, $escapedOld)
        $proseMentions = $bodyMatchList.Count
        if ($proseMentions -gt 0 -and $RewriteProse) {
            $updatedBody = $body.Replace($OldName, $NewName)
            $changes += $proseMentions
            $proseMentions = 0
        }
    }

    $rebuilt = "$preFm$updatedFm$postFm$updatedBody"

    return @{
        Content       = $rebuilt
        Changes       = $changes
        ProseMentions = $proseMentions
    }
}

function Update-CoreManifestAgentMaturity {
    <#
    .SYNOPSIS
        Rewrites a single agent's maturity value in the central collections manifest.
    .DESCRIPTION
        Locates the agent entry by its manifest 'path:' value (which is immediately
        followed by the 'maturity:' line in every manifest agent block) and replaces
        the maturity value in place. Returns a result hashtable describing the
        outcome without writing to disk; callers persist the returned content.
    .PARAMETER Content
        Full manifest file content to transform.
    .PARAMETER AgentRelativePath
        Repository-relative agent path (forward-slash normalized) used as the manifest key.
    .PARAMETER NewMaturity
        Target maturity value to write.
    .OUTPUTS
        [hashtable] With Updated, OldMaturity, NewMaturity, Content, and Reason keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentRelativePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('experimental', 'preview', 'stable')]
        [string]$NewMaturity
    )

    $escapedPath = [regex]::Escape($AgentRelativePath)
    $pattern = "(?m)^(?<pre>[ \t]+path:[ \t]*$escapedPath[ \t]*\r?\n[ \t]+maturity:[ \t]*)(?<mval>\S+)"
    $match = [regex]::Match($Content, $pattern)

    if (-not $match.Success) {
        return @{ Updated = $false; OldMaturity = $null; NewMaturity = $NewMaturity; Content = $Content; Reason = 'entry-not-found' }
    }

    $oldMaturity = $match.Groups['mval'].Value
    if ($oldMaturity -eq $NewMaturity) {
        return @{ Updated = $false; OldMaturity = $oldMaturity; NewMaturity = $NewMaturity; Content = $Content; Reason = 'already-aligned' }
    }

    $replacement = "$($match.Groups['pre'].Value)$NewMaturity"
    $updated = $Content.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)

    return @{ Updated = $true; OldMaturity = $oldMaturity; NewMaturity = $NewMaturity; Content = $updated; Reason = 'updated' }
}

function Invoke-AgentPromotion {
    <#
    .SYNOPSIS
        Promotes an agent to a new maturity tier and rewrites references.
    .DESCRIPTION
        Computes the new picker name from the target agent's existing name and the
        target maturity suffix, then rewrites the target file and every referring
        agent file under .github/agents. Also synchronizes the agent's maturity tier
        in the central collections manifest. Returns a result hashtable summarizing
        the changes.
    .PARAMETER AgentPath
        Path to the target agent file.
    .PARAMETER TargetMaturity
        Target maturity tier: experimental, preview, or stable.
    .PARAMETER RepoRoot
        Repository root containing .github/agents.
    .PARAMETER RewriteProse
        Rewrite prose mentions of the previous suffixed name.
    .PARAMETER ManifestPath
        Path to the central collections manifest. Defaults to
        collections/core-manifest.yml under RepoRoot.
    .OUTPUTS
        [hashtable] With OldName, NewName, FilesChanged, ReferencesRewritten,
        ProseWarnings, ManifestUpdated, ManifestOldMaturity, and ManifestNewMaturity keys.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('experimental', 'preview', 'stable')]
        [string]$TargetMaturity,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter()]
        [switch]$RewriteProse,

        [Parameter()]
        [string]$ManifestPath
    )

    $resolvedTarget = Resolve-Path -LiteralPath $AgentPath -ErrorAction Stop
    $targetPath = $resolvedTarget.Path

    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        throw "Agent path '$AgentPath' does not exist."
    }
    if ($targetPath -notmatch '\.agent\.md$') {
        throw "Agent path '$AgentPath' must end with .agent.md."
    }

    $frontmatter = Get-ArtifactFrontmatter -FilePath $targetPath
    if ($null -eq $frontmatter.name) {
        throw "Target agent '$AgentPath' is missing required 'name' frontmatter field."
    }

    $oldName = [string]$frontmatter.name
    $baseName = Get-AgentBaseName -Name $oldName
    $newSuffix = Get-AgentMaturityNameSuffix -Maturity $TargetMaturity
    $newName = if ([string]::IsNullOrEmpty($newSuffix)) { $baseName } else { "$baseName $newSuffix" }

    $result = @{
        OldName             = $oldName
        NewName             = $newName
        FilesChanged        = 0
        ReferencesRewritten = 0
        ProseWarnings       = @()
        NoOp                = $false
        ManifestUpdated     = $false
        ManifestOldMaturity = $null
        ManifestNewMaturity = $TargetMaturity
        ManifestReason      = $null
    }

    if ($oldName -eq $newName) {
        $result.NoOp = $true
        return $result
    }

    $referenceFiles = Get-AgentReferenceFile -RepoRoot $RepoRoot

    $pendingWrites = @()
    foreach ($file in $referenceFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        if ($null -eq $content) {
            $content = ''
        }
        $isTarget = [string]::Equals($file.FullName, $targetPath, [System.StringComparison]::OrdinalIgnoreCase)

        $rewrite = Update-AgentNameReference -Content $content `
            -OldName $oldName `
            -NewName $newName `
            -IsTarget:$isTarget `
            -RewriteProse:$RewriteProse

        if ($rewrite.ProseMentions -gt 0) {
            $relPath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'
            $result.ProseWarnings += [pscustomobject]@{
                File     = $relPath
                Mentions = $rewrite.ProseMentions
            }
        }

        if ($rewrite.Changes -gt 0) {
            $result.ReferencesRewritten += $rewrite.Changes
            $result.FilesChanged++
            $pendingWrites += [pscustomobject]@{
                Path    = $file.FullName
                Content = $rewrite.Content
                Changes = $rewrite.Changes
            }
        }
    }

    foreach ($write in $pendingWrites) {
        $relPath = [System.IO.Path]::GetRelativePath($RepoRoot, $write.Path) -replace '\\', '/'
        $description = "Rewrite $($write.Changes) reference(s) in $relPath"
        if ($PSCmdlet.ShouldProcess($write.Path, $description)) {
            Set-Content -LiteralPath $write.Path -Value $write.Content -Encoding utf8NoBOM -NoNewline
        }
    }

    $resolvedManifestPath = if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
        Join-Path $RepoRoot 'collections/core-manifest.yml'
    }
    else {
        $ManifestPath
    }

    if (-not (Test-Path -LiteralPath $resolvedManifestPath)) {
        $result.ManifestReason = 'manifest-not-found'
        Write-Warning "Collections manifest '$resolvedManifestPath' not found; skipping maturity sync."
    }
    else {
        $agentRelativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $targetPath) -replace '\\', '/'
        $manifestContent = Get-Content -LiteralPath $resolvedManifestPath -Raw
        $manifestResult = Update-CoreManifestAgentMaturity -Content $manifestContent `
            -AgentRelativePath $agentRelativePath `
            -NewMaturity $TargetMaturity

        $result.ManifestOldMaturity = $manifestResult.OldMaturity
        $result.ManifestReason = $manifestResult.Reason

        if ($manifestResult.Updated) {
            $manifestRelPath = [System.IO.Path]::GetRelativePath($RepoRoot, $resolvedManifestPath) -replace '\\', '/'
            $description = "Update maturity '$($manifestResult.OldMaturity)' -> '$TargetMaturity' for $agentRelativePath in $manifestRelPath"
            if ($PSCmdlet.ShouldProcess($resolvedManifestPath, $description)) {
                Set-Content -LiteralPath $resolvedManifestPath -Value $manifestResult.Content -Encoding utf8NoBOM -NoNewline
            }
            $result.ManifestUpdated = $true
        }
        elseif ($manifestResult.Reason -eq 'entry-not-found') {
            Write-Warning "Agent '$agentRelativePath' not found in collections manifest; skipping maturity sync."
        }
    }

    return $result
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ([string]::IsNullOrWhiteSpace($AgentPath)) {
            throw "The -AgentPath parameter is required. Example: npm run promote:agent -- -AgentPath <path> -TargetMaturity <maturity>"
        }
        if ([string]::IsNullOrWhiteSpace($TargetMaturity)) {
            throw "The -TargetMaturity parameter is required. Valid values: experimental, preview, stable."
        }

        if ($DryRun) {
            $WhatIfPreference = $true
        }

        $result = Invoke-AgentPromotion `
            -AgentPath $AgentPath `
            -TargetMaturity $TargetMaturity `
            -RepoRoot $RepoRoot `
            -RewriteProse:$RewriteProse `
            -ManifestPath $ManifestPath `
            -WhatIf:$WhatIfPreference `
            -Confirm:$ConfirmPreference

        Write-Host ''
        if ($result.NoOp) {
            Write-Host "Agent name '$($result.OldName)' is already aligned with target maturity; no changes required." -ForegroundColor Yellow
            exit 0
        }

        Write-Host "Promotion summary:" -ForegroundColor Green
        Write-Host "  Old name:             $($result.OldName)"
        Write-Host "  New name:             $($result.NewName)"
        Write-Host "  Files changed:        $($result.FilesChanged)"
        Write-Host "  References rewritten: $($result.ReferencesRewritten)"
        if ($result.ManifestUpdated) {
            Write-Host "  Manifest maturity:    $($result.ManifestOldMaturity) -> $($result.ManifestNewMaturity)"
        }
        elseif ($result.ManifestReason -eq 'entry-not-found') {
            Write-Host "  Manifest maturity:    skipped (agent not found in manifest)" -ForegroundColor Yellow
        }
        elseif ($result.ManifestReason -eq 'manifest-not-found') {
            Write-Host "  Manifest maturity:    skipped (manifest not found)" -ForegroundColor Yellow
        }

        if ($result.ProseWarnings.Count -gt 0) {
            Write-Host ''
            Write-Warning "Found prose mentions of '$($result.OldName)' that were not rewritten (use -RewriteProse to apply):"
            foreach ($warn in $result.ProseWarnings) {
                Write-Host "  $($warn.File) ($($warn.Mentions) mention(s))" -ForegroundColor Yellow
            }
        }

        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Promote-Agent failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
