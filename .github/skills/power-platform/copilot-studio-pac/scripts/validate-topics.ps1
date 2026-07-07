#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Static topic-integrity linter for a Copilot Studio agent scaffold.

.DESCRIPTION
    Executable companion to the prose "pre-pack topic-integrity gate". Parses the
    hand-authored (and packed) *.mcs.yml topic files and fails closed on the
    structural defect classes that otherwise only surface at runtime after a
    deploy: unbound tokens, non-schema skeletons, system-trigger collisions,
    duplicate system triggers, componentName/filename drift and topicCount drift.

    The gate discovers topics under a scaffold root (workspace/topics/*.mcs.yml,
    or a nested workspace/topics tree, or a bare directory of *.mcs.yml files),
    validates each topic against per-topic and cross-topic invariants, and
    reconciles the OnRecognizedIntent (custom) topic count against a discovered
    or supplied state.json. Every invariant, message substring, and exit code is
    a faithful port of the original Node implementation.

    Exit codes:
      0  every topic passes every invariant (and topicCount reconciles)
      1  one or more topics FAIL, or the topicCount reconciliation fails
      2  usage / parse / IO / missing-dependency error

.PARAMETER Path
    A scaffold root (auto-discovers workspace/topics/*.mcs.yml) OR a directory
    that directly contains *.mcs.yml files. When both a workspace/topics tree and
    loose files exist, workspace/topics wins.

.PARAMETER StatePath
    Explicit path to a state.json used for topicCount reconciliation. When
    omitted, a state.json is auto-discovered under the scaffold root (preferring
    one inside a .copilot-tracking directory, else a top-level state.json).

.PARAMETER JsonOut
    Optional path to write a machine-readable JSON report of the run.

.PARAMETER AllowPrefix
    Declared variable namespaces whose first token segment is considered bound.
    A {Name.Path} token whose first segment is not in this set is reported as an
    undeclared token. Defaults to System, Topic, Global, Env.

.EXAMPLE
    ./validate-topics.ps1 -Path ../../../../scaffold/power-platform/copilot-studio/my-agent
    Discovers and validates the topics under a scaffold root.

.EXAMPLE
    ./validate-topics.ps1 -Path <scaffold-root> -StatePath <state.json> -JsonOut out.json
    Validates topics, reconciles against an explicit state.json and writes a JSON report.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path,

    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$StatePath,

    [Parameter()]
    [string]$JsonOut,

    [Parameter()]
    [string[]]$AllowPrefix = @('System', 'Topic', 'Global', 'Env')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Dependency guard. powershell-yaml is the repo-pinned YAML parser; zero other
# third-party dependencies are introduced. A missing or unimportable module is
# a fail-closed environment error and MUST exit 2 (never 1), matching the
# original Node behavior and the SKILL.md Troubleshooting contract. Write-Error
# uses -ErrorAction Continue so $ErrorActionPreference = 'Stop' does not promote
# it to a terminating error before the explicit `exit 2`.
# ---------------------------------------------------------------------------
function Test-YamlModuleAvailable {
    <#
    .SYNOPSIS
        True when the repo-pinned powershell-yaml module is installed and
        discoverable via Get-Module -ListAvailable. Extracted so the
        missing-dependency decision is unit-testable in isolation.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Module -ListAvailable -Name 'powershell-yaml')
}

if (-not (Test-YamlModuleAvailable)) {
    Write-Error -ErrorAction Continue "Required module 'powershell-yaml' is not installed. Run 'Install-Module powershell-yaml -Scope CurrentUser' before invoking this script."
    exit 2
}
try {
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    Write-Error -ErrorAction Continue "Failed to import required module 'powershell-yaml': $($_.Exception.Message)"
    exit 2
}

#region Model

# System-trigger model. Copilot Studio permits at most one topic per system
# trigger kind, and component identity on `pac copilot pack` derives from
# `componentName`, NOT the filename. A custom topic authored with a system
# trigger kind silently collapses into the built-in topic of that kind.
$script:Canon = [ordered]@{
    OnConversationStart = @{ name = 'ConversationStart'; display = 'Conversation Start' }
    OnUnknownIntent     = @{ name = 'Fallback'; display = 'Fallback' }
    OnEscalate          = @{ name = 'Escalate'; display = 'Escalate' }
    OnError             = @{ name = 'OnError'; display = 'On Error' }
    OnSignIn            = @{ name = 'Signin'; display = 'Sign in' }
}
$script:SystemTriggerKinds = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$script:Canon.Keys, [System.StringComparer]::Ordinal)
$script:CustomTriggerKind = 'OnRecognizedIntent'

# A real mcs variable reference is a dotted identifier path: {balance},
# {System.Bot.Name}, {Topic.Answer}. Serialized Adaptive-Card JSON bodies and
# prose with braces are NOT variable refs and must not be flagged.
$script:TokenRegex = [regex]'\{([^{}]+)\}'
$script:VarTokenRegex = [regex]'^[A-Za-z_][\w]*(\s*\.\s*[A-Za-z_][\w]*)*$'

#endregion Model

#region Functions

function Get-MapValue {
    <#
    .SYNOPSIS
        Case-sensitive lookup of a single key on an IDictionary (mirrors JS
        object property access, which is case-sensitive).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Map,

        [Parameter(Mandatory)]
        [string]$Key
    )

    if ($null -eq $Map -or -not ($Map -is [System.Collections.IDictionary])) {
        return $null
    }
    foreach ($k in $Map.Keys) {
        if ($k -is [string] -and $k -ceq $Key) {
            return $Map[$k]
        }
    }
    return $null
}

function Get-NormalizedName {
    <#
    .SYNOPSIS
        Normalize a topic name for filename <-> componentName comparison:
        strip all whitespace and case-fold.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter()][string]$Value)

    return ($Value -replace '\s+', '').ToLowerInvariant()
}

function Test-LegitSystemTopic {
    <#
    .SYNOPSIS
        A topic is a legitimate system-topic customization only when its trigger
        kind is a system trigger AND BOTH its filename base AND its componentName
        match that kind's canonical or display name (case-sensitive).

    .DESCRIPTION
        A genuine system-topic customization always has filename ==
        componentName == the canonical (or display) name. Requiring the
        componentName half closes a fail-open hole: a file literally named
        `OnError.mcs.yml` with a custom componentName (e.g. `RefundHandler`) and
        `beginDialog.kind: OnError` would otherwise be treated as legit, yet on
        `pac copilot pack` it collapses into the built-in On Error topic. When
        componentName is null/empty, the topic is NOT legit.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()][string]$TriggerKind,
        [Parameter()][string]$Base,
        [Parameter()][string]$ComponentName
    )

    if (-not $script:SystemTriggerKinds.Contains($TriggerKind)) {
        return $false
    }
    $canon = $script:Canon[$TriggerKind]
    $baseMatches = ($Base -ceq $canon.name -or $Base -ceq $canon.display)
    $componentMatches = ($ComponentName -and ($ComponentName -ceq $canon.name -or $ComponentName -ceq $canon.display))
    return ($baseMatches -and $componentMatches)
}

function Get-McsFile {
    <#
    .SYNOPSIS
        Return the sorted full paths of the *.mcs.yml files in a directory
        (case-insensitive suffix match).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)][string]$Directory)

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return @()
    }
    return Get-ChildItem -LiteralPath $Directory -File |
        Where-Object { $_.Name.ToLowerInvariant().EndsWith('.mcs.yml') } |
        Sort-Object -Property Name |
        ForEach-Object { $_.FullName }
}

function Test-DirHasMcs {
    <#
    .SYNOPSIS
        True when the directory exists and holds at least one *.mcs.yml file.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Directory)

    return @(Get-McsFile -Directory $Directory).Count -gt 0
}

function Find-WorkspaceTopics {
    <#
    .SYNOPSIS
        Bounded recursive search (max depth 6) for a `<...>/workspace/topics`
        directory holding *.mcs.yml files. Skips node_modules and .git. Returns
        the first match via deterministic alphabetical depth-first traversal.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter()][int]$MaxDepth = 6,
        [Parameter()][int]$Depth = 0
    )

    $candidate = Join-Path -Path (Join-Path -Path $Root -ChildPath 'workspace') -ChildPath 'topics'
    if (Test-DirHasMcs -Directory $candidate) {
        return $candidate
    }
    if ($Depth -ge $MaxDepth) {
        return $null
    }

    $children = @()
    try {
        $children = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction Stop | Sort-Object -Property Name
    }
    catch {
        return $null
    }
    foreach ($child in $children) {
        if ($child.Name -eq 'node_modules' -or $child.Name -eq '.git') {
            continue
        }
        $found = Find-WorkspaceTopics -Root $child.FullName -MaxDepth $MaxDepth -Depth ($Depth + 1)
        if ($found) {
            return $found
        }
    }
    return $null
}

function Find-StateFile {
    <#
    .SYNOPSIS
        Find the first state.json under `root` living inside a `.copilot-tracking`
        directory; otherwise a top-level `<root>/state.json`. Searches only UNDER
        the root (never upward), max depth 8, skipping node_modules and .git.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter()][int]$MaxDepth = 8
    )

    $tracked = Find-TrackedStateFile -Root $Root -MaxDepth $MaxDepth -Depth 0
    if ($tracked) {
        return $tracked
    }
    $top = Join-Path -Path $Root -ChildPath 'state.json'
    if (Test-Path -LiteralPath $top -PathType Leaf) {
        return $top
    }
    return $null
}

function Find-TrackedStateFile {
    <#
    .SYNOPSIS
        Recursive helper for Find-StateFile: returns the first state.json whose
        full path contains a `.copilot-tracking` segment.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][int]$MaxDepth,
        [Parameter(Mandatory)][int]$Depth
    )

    $entries = @()
    try {
        $entries = Get-ChildItem -LiteralPath $Root -Force -ErrorAction Stop | Sort-Object -Property Name
    }
    catch {
        return $null
    }

    foreach ($entry in $entries) {
        if ($entry.PSIsContainer) {
            continue
        }
        if ($entry.Name -eq 'state.json') {
            $segments = $entry.FullName -split '[\\/]'
            if ($segments -contains '.copilot-tracking') {
                return $entry.FullName
            }
        }
    }

    if ($Depth -ge $MaxDepth) {
        return $null
    }
    foreach ($entry in $entries) {
        if (-not $entry.PSIsContainer) {
            continue
        }
        if ($entry.Name -eq 'node_modules' -or $entry.Name -eq '.git') {
            continue
        }
        $found = Find-TrackedStateFile -Root $entry.FullName -MaxDepth $MaxDepth -Depth ($Depth + 1)
        if ($found) {
            return $found
        }
    }
    return $null
}

function Resolve-TopicSet {
    <#
    .SYNOPSIS
        Resolve a scaffold root or topics directory to the concrete set of
        *.mcs.yml files, honoring discovery precedence: immediate
        workspace/topics, then a nested workspace/topics tree, then the path
        itself as a directory of *.mcs.yml files.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $abs = (Resolve-Path -LiteralPath $Path).ProviderPath

    $immediate = Join-Path -Path (Join-Path -Path $abs -ChildPath 'workspace') -ChildPath 'topics'
    if (Test-DirHasMcs -Directory $immediate) {
        return [pscustomobject]@{ TopicsDir = $immediate; Files = @(Get-McsFile -Directory $immediate); Root = $abs }
    }

    $found = Find-WorkspaceTopics -Root $abs
    if ($found) {
        return [pscustomobject]@{ TopicsDir = $found; Files = @(Get-McsFile -Directory $found); Root = $abs }
    }

    if (Test-DirHasMcs -Directory $abs) {
        return [pscustomobject]@{ TopicsDir = $abs; Files = @(Get-McsFile -Directory $abs); Root = $abs }
    }

    throw "no *.mcs.yml topic files found under $abs"
}

function Get-StringScalar {
    <#
    .SYNOPSIS
        Recursively emit every string scalar reachable from a parsed YAML node.
        Recurses dictionaries by value and enumerables by element, with a
        reference-identity cycle guard. Strings are written to the pipeline so
        the caller can collect them with @(...).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()][object]$Node,
        [Parameter()][System.Collections.Generic.HashSet[object]]$Seen
    )

    if ($null -eq $Seen) {
        $Seen = [System.Collections.Generic.HashSet[object]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance)
    }

    if ($null -eq $Node) {
        return
    }
    if ($Node -is [string]) {
        Write-Output -InputObject $Node
        return
    }
    if ($Node -is [System.Collections.IDictionary]) {
        if (-not $Seen.Add($Node)) { return }
        foreach ($value in $Node.Values) {
            Get-StringScalar -Node $value -Seen $Seen
        }
        return
    }
    if ($Node -is [System.Collections.IEnumerable]) {
        if (-not $Seen.Add($Node)) { return }
        foreach ($value in $Node) {
            Get-StringScalar -Node $value -Seen $Seen
        }
        return
    }
}

function Find-UndeclaredToken {
    <#
    .SYNOPSIS
        Scan every string scalar (excluding the authoring-only mcs.metadata
        subtree) for {Name.Path} tokens whose first segment is not a declared
        namespace prefix. Power Fx expressions (scalars starting with `=`) are
        never scanned.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()][object]$Doc,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[string]]$AllowSet
    )

    $seen = [System.Collections.Generic.HashSet[object]]::new([System.Collections.Generic.ReferenceEqualityComparer]::Instance)
    $strings = @(
        if ($Doc -is [System.Collections.IDictionary]) {
            foreach ($k in $Doc.Keys) {
                if ($k -is [string] -and $k -ceq 'mcs.metadata') {
                    continue
                }
                Get-StringScalar -Node $Doc[$k] -Seen $seen
            }
        }
        else {
            Get-StringScalar -Node $Doc -Seen $seen
        }
    )

    $bad = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($s in $strings) {
        if ($s.Trim().StartsWith('=')) {
            continue
        }
        foreach ($match in $script:TokenRegex.Matches($s)) {
            $inner = $match.Groups[1].Value.Trim()
            if (-not $script:VarTokenRegex.IsMatch($inner)) {
                continue
            }
            $firstSegment = ($inner -split '\.')[0].Trim()
            if (-not $AllowSet.Contains($firstSegment)) {
                [void]$bad.Add("{$($match.Groups[1].Value)}")
            }
        }
    }

    return @($bad | Sort-Object)
}

function Test-Topic {
    <#
    .SYNOPSIS
        Validate a single topic file against the structural and token invariants.
        Cross-topic invariants are applied afterwards over the whole set.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[string]]$AllowSet
    )

    $base = [regex]::Replace([System.IO.Path]::GetFileName($File), '\.mcs\.yml$', '', 'IgnoreCase')
    $result = [pscustomobject]@{
        file            = [System.IO.Path]::GetFileName($File)
        path            = $File
        base            = $base
        componentName   = $null
        triggerKind     = $null
        isSystemTrigger = $false
        isLegitSystem   = $false
        parseError      = $false
        fails           = [System.Collections.Generic.List[object]]::new()
        warns           = [System.Collections.Generic.List[object]]::new()
    }

    $text = $null
    try {
        $text = Get-Content -LiteralPath $File -Raw -ErrorAction Stop
    }
    catch {
        [void]$result.fails.Add([pscustomobject]@{ invariant = 'io'; message = "cannot read file: $($_.Exception.Message)" })
        return $result
    }

    $doc = $null
    try {
        $doc = ConvertFrom-Yaml $text
    }
    catch {
        $result.parseError = $true
        [void]$result.fails.Add([pscustomobject]@{ invariant = 'schema-parse'; message = "YAML parse error: $($_.Exception.Message)" })
        return $result
    }

    if ($null -eq $doc -or -not ($doc -is [System.Collections.IDictionary])) {
        [void]$result.fails.Add([pscustomobject]@{ invariant = 'schema-skeleton'; message = 'file does not parse to a mapping' })
        return $result
    }

    try {
        $meta = Get-MapValue -Map $doc -Key 'mcs.metadata'
        $componentNameRaw = if ($meta -is [System.Collections.IDictionary]) { Get-MapValue -Map $meta -Key 'componentName' } else { $null }
        $topKind = Get-MapValue -Map $doc -Key 'kind'
        $beginDialog = Get-MapValue -Map $doc -Key 'beginDialog'
        $triggerKindRaw = Get-MapValue -Map $beginDialog -Key 'kind'
        $bdId = Get-MapValue -Map $beginDialog -Key 'id'

        $result.componentName = if ($componentNameRaw -is [string] -and $componentNameRaw.Length -gt 0) { $componentNameRaw } else { $null }
        $result.triggerKind = if ($triggerKindRaw -is [string] -and $triggerKindRaw.Length -gt 0) { $triggerKindRaw } else { $null }
        $result.isSystemTrigger = ($null -ne $result.triggerKind) -and $script:SystemTriggerKinds.Contains($result.triggerKind)
        $result.isLegitSystem = Test-LegitSystemTopic -TriggerKind $result.triggerKind -Base $base -ComponentName $result.componentName

        # (1) schema-skeleton -------------------------------------------------
        $skeletonMisses = [System.Collections.Generic.List[string]]::new()
        if (-not $result.componentName) { $skeletonMisses.Add('mcs.metadata.componentName') }
        if ($topKind -cne 'AdaptiveDialog') { $skeletonMisses.Add('kind: AdaptiveDialog') }
        if (-not $result.triggerKind) { $skeletonMisses.Add('beginDialog.kind') }
        if ($bdId -cne 'main') { $skeletonMisses.Add('beginDialog.id: main') }
        if ($skeletonMisses.Count -gt 0) {
            [void]$result.fails.Add([pscustomobject]@{ invariant = 'schema-skeleton'; message = "missing/invalid: $($skeletonMisses -join ', ')" })
        }
        if ($meta -is [System.Collections.IDictionary]) {
            $description = Get-MapValue -Map $meta -Key 'description'
            if (-not ($description -is [string] -and $description.Length -gt 0)) {
                [void]$result.warns.Add([pscustomobject]@{ invariant = 'schema-skeleton'; message = 'mcs.metadata.description missing' })
            }
        }

        # (2) undeclared-tokens -----------------------------------------------
        $badTokens = @(Find-UndeclaredToken -Doc $doc -AllowSet $AllowSet)
        if ($badTokens.Count -gt 0) {
            [void]$result.fails.Add([pscustomobject]@{ invariant = 'undeclared-tokens'; message = "undeclared token(s): $($badTokens -join ', ')" })
        }

        # (3) system-trigger-collision ---------------------------------------
        if ($result.isSystemTrigger -and -not $result.isLegitSystem) {
            $canonName = $script:Canon[$result.triggerKind].name
            [void]$result.fails.Add([pscustomobject]@{
                    invariant = 'system-trigger-collision'
                    message   = "custom topic '$($result.file)' uses system trigger kind '$($result.triggerKind)' -> will collapse into the built-in '$canonName' topic on pack"
                })
        }

        # (3b) reserved-name collision ---------------------------------------
        if (-not $result.isSystemTrigger -and $result.componentName) {
            $cn = Get-NormalizedName -Value $result.componentName
            $hit = $null
            foreach ($canon in $script:Canon.Values) {
                if ((Get-NormalizedName -Value $canon.name) -eq $cn -or (Get-NormalizedName -Value $canon.display) -eq $cn) {
                    $hit = $canon
                    break
                }
            }
            if ($hit) {
                [void]$result.fails.Add([pscustomobject]@{
                        invariant = 'reserved-name-collision'
                        message   = "custom topic '$($result.file)' has componentName '$($result.componentName)' which collapses into the built-in '$($hit.name)' topic on pack"
                    })
            }
        }

        # (5a) filename == componentName (custom + masquerading topics only) --
        if (-not $result.isLegitSystem -and $result.componentName -and
            (Get-NormalizedName -Value $base) -ne (Get-NormalizedName -Value $result.componentName)) {
            [void]$result.fails.Add([pscustomobject]@{
                    invariant = 'filename-mismatch'
                    message   = "filename '$base' != componentName '$($result.componentName)'"
                })
        }

        return $result
    }
    catch {
        [void]$result.fails.Add([pscustomobject]@{ invariant = 'internal-error'; message = "unexpected error while validating: $($_.Exception.Message)" })
        return $result
    }
}

function Test-DuplicateSystemTrigger {
    <#
    .SYNOPSIS
        Cross-topic invariant: at most one topic per system trigger kind. Any
        kind defined by more than one topic FAILs every topic in that group.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results)

    $byKind = [ordered]@{}
    foreach ($r in $Results) {
        if (-not $r.isSystemTrigger) { continue }
        if (-not $byKind.Contains($r.triggerKind)) {
            $byKind[$r.triggerKind] = [System.Collections.Generic.List[object]]::new()
        }
        [void]$byKind[$r.triggerKind].Add($r)
    }
    foreach ($kind in $byKind.Keys) {
        $group = $byKind[$kind]
        if ($group.Count -gt 1) {
            $names = ($group | ForEach-Object { $_.file }) -join ', '
            foreach ($r in $group) {
                [void]$r.fails.Add([pscustomobject]@{
                        invariant = 'duplicate-system-trigger'
                        message   = "system trigger kind '$kind' is defined by $($group.Count) topics ($names); at most one is allowed"
                    })
            }
        }
    }
}

function Test-ComponentNameUniqueness {
    <#
    .SYNOPSIS
        Cross-topic invariant: componentName uniqueness. Any name shared by more
        than one topic FAILs every topic that carries it.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results)

    $byName = [ordered]@{}
    foreach ($r in $Results) {
        if (-not $r.componentName) { continue }
        if (-not $byName.Contains($r.componentName)) {
            $byName[$r.componentName] = [System.Collections.Generic.List[object]]::new()
        }
        [void]$byName[$r.componentName].Add($r)
    }
    foreach ($name in $byName.Keys) {
        $group = $byName[$name]
        if ($group.Count -gt 1) {
            $files = ($group | ForEach-Object { $_.file }) -join ', '
            foreach ($r in $group) {
                [void]$r.fails.Add([pscustomobject]@{
                        invariant = 'componentName-uniqueness'
                        message   = "componentName '$name' is shared by $($group.Count) topics ($files)"
                    })
            }
        }
    }
}

function Get-TopicCountReconciliation {
    <#
    .SYNOPSIS
        Reconcile the recorded topicCount in state.json against the count of
        custom (OnRecognizedIntent) topic files. Fails closed when state.json
        cannot be read or parsed, or when the recorded count is non-numeric.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results
    )

    $customCount = @($Results | Where-Object { $_.triggerKind -ceq $script:CustomTriggerKind }).Count

    $state = $null
    try {
        $state = Get-Content -LiteralPath $StatePath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable
    }
    catch {
        return [pscustomobject]@{
            ok = $false; warn = $false; error = "cannot read/parse state.json: $($_.Exception.Message)"
            recorded = $null; customCount = $customCount; statePath = $StatePath; message = $null
        }
    }

    $phases = Get-MapValue -Map $state -Key 'phases'
    $topics = Get-MapValue -Map $phases -Key 'topics'
    $recorded = Get-MapValue -Map $topics -Key 'topicCount'

    if ($null -eq $recorded) {
        return [pscustomobject]@{
            ok = $true; warn = $true; error = $null; recorded = $null; customCount = $customCount
            statePath = $StatePath; message = 'state.phases.topics.topicCount is absent; reconciliation skipped'
        }
    }

    $coerced = $null
    if ($recorded -is [bool]) {
        $coerced = [double]([int]$recorded)
    }
    elseif ($recorded -is [byte] -or $recorded -is [int16] -or $recorded -is [int32] -or $recorded -is [int64] -or
        $recorded -is [uint16] -or $recorded -is [uint32] -or $recorded -is [uint64] -or
        $recorded -is [single] -or $recorded -is [double] -or $recorded -is [decimal]) {
        $coerced = [double]$recorded
    }
    elseif ($recorded -is [string]) {
        if ($recorded.Trim().Length -eq 0) {
            $coerced = 0.0
        }
        else {
            $parsed = 0.0
            if ([double]::TryParse($recorded, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
                $coerced = $parsed
            }
        }
    }

    if ($null -eq $coerced) {
        return [pscustomobject]@{
            ok = $false; warn = $false
            error = "state.phases.topics.topicCount present but non-numeric ($(ConvertTo-Json -InputObject $recorded -Compress)); cannot reconcile"
            recorded = $null; customCount = $customCount; statePath = $StatePath; message = $null
        }
    }

    return [pscustomobject]@{
        ok = ($coerced -eq $customCount); warn = $false; error = $null; recorded = $coerced; customCount = $customCount
        statePath = $StatePath
        message = "state.phases.topics.topicCount=$recorded vs custom ($script:CustomTriggerKind) topic files=$customCount"
    }
}

function Write-TopicReport {
    <#
    .SYNOPSIS
        Emit the human-readable topic-integrity report to the host (stdout).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TopicsDir,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results,
        [Parameter()][object]$Reconciliation,
        [Parameter(Mandatory)][int]$PassCount,
        [Parameter(Mandatory)][int]$FailCount,
        [Parameter(Mandatory)][bool]$ReconciliationFailed
    )

    Write-Host "Topic-integrity gate $([char]0x2014) $TopicsDir"

    foreach ($r in $Results) {
        $passed = $r.fails.Count -eq 0
        $invariants = @($r.fails | ForEach-Object { $_.invariant } | Select-Object -Unique)
        $suffix = if ($invariants.Count -gt 0) { "  [$($invariants -join ', ')]" } else { '' }
        Write-Host "$(if ($passed) { 'PASS' } else { 'FAIL' })  $($r.file)$suffix"
        foreach ($f in $r.fails) {
            Write-Host "        $($f.invariant): $($f.message)"
        }
        foreach ($w in $r.warns) {
            Write-Host "        warn $($w.invariant): $($w.message)"
        }
    }

    if ($Reconciliation) {
        if ($Reconciliation.error) {
            Write-Host "SCAFFOLD FAIL  topicCount-reconciliation: $($Reconciliation.error)"
        }
        elseif ($Reconciliation.warn) {
            Write-Host "SCAFFOLD WARN  topicCount-reconciliation: $($Reconciliation.message)"
        }
        elseif (-not $Reconciliation.ok) {
            Write-Host "SCAFFOLD FAIL  topicCount-reconciliation: $($Reconciliation.message)"
        }
        else {
            Write-Host "SCAFFOLD PASS  topicCount-reconciliation: $($Reconciliation.message)"
        }
    }
    else {
        Write-Host 'SCAFFOLD ----  topicCount-reconciliation: no state.json found (skipped)'
    }

    Write-Host ''
    $summary = "$($Results.Count) topics, $PassCount pass, $FailCount fail"
    if ($ReconciliationFailed) {
        $summary += ' + topicCount-reconciliation FAIL'
    }
    Write-Host $summary
}

function Invoke-TopicIntegrityGate {
    <#
    .SYNOPSIS
        Run the full topic-integrity gate and return the process exit code
        (0 clean, 1 topic/reconciliation FAIL, 2 parse error).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][string]$StatePath,
        [Parameter()][string]$JsonOut,
        [Parameter()][string[]]$AllowPrefix = @('System', 'Topic', 'Global', 'Env')
    )

    $allowSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$AllowPrefix, [System.StringComparer]::Ordinal)
    $topicSet = Resolve-TopicSet -Path $Path

    $results = @(foreach ($file in $topicSet.Files) { Test-Topic -File $file -AllowSet $allowSet })
    Test-DuplicateSystemTrigger -Results $results
    Test-ComponentNameUniqueness -Results $results

    # Reconciliation: explicit -StatePath wins; else auto-discover under the root.
    $resolvedStatePath = $null
    if (-not [string]::IsNullOrEmpty($StatePath)) {
        $resolvedStatePath = $StatePath
    }
    else {
        $resolvedStatePath = Find-StateFile -Root $topicSet.Root
    }
    $reconciliation = if ($resolvedStatePath) { Get-TopicCountReconciliation -StatePath $resolvedStatePath -Results $results } else { $null }

    $passCount = @($results | Where-Object { $_.fails.Count -eq 0 }).Count
    $failCount = $results.Count - $passCount
    $parseError = @($results | Where-Object { $_.parseError }).Count -gt 0

    $reconciliationFailed = $false
    if ($reconciliation) {
        if ($reconciliation.error) { $reconciliationFailed = $true }
        elseif ($reconciliation.warn) { $reconciliationFailed = $false }
        elseif (-not $reconciliation.ok) { $reconciliationFailed = $true }
    }

    Write-TopicReport -TopicsDir $topicSet.TopicsDir -Results $results -Reconciliation $reconciliation `
        -PassCount $passCount -FailCount $failCount -ReconciliationFailed $reconciliationFailed

    if (-not [string]::IsNullOrEmpty($JsonOut)) {
        $payload = [pscustomobject]@{
            target  = $topicSet.TopicsDir
            summary = [pscustomobject]@{ topics = $results.Count; pass = $passCount; fail = $failCount; reconciliationFailed = $reconciliationFailed }
            reconciliation = $reconciliation
            results = @($results | ForEach-Object {
                    [pscustomobject]@{
                        file          = $_.file
                        pass          = ($_.fails.Count -eq 0)
                        componentName = $_.componentName
                        triggerKind   = $_.triggerKind
                        fails         = @($_.fails)
                        warns         = @($_.warns)
                    }
                })
        }
        try {
            $payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $JsonOut -Encoding utf8 -ErrorAction Stop
        }
        catch {
            throw "cannot write -JsonOut output: $($_.Exception.Message)"
        }
    }

    if ($parseError) {
        return 2
    }
    if ($failCount -gt 0 -or $reconciliationFailed) {
        return 1
    }
    return 0
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $code = Invoke-TopicIntegrityGate -Path $Path -StatePath $StatePath -JsonOut $JsonOut -AllowPrefix $AllowPrefix
        exit $code
    }
    catch {
        Write-Error -ErrorAction Continue "validate-topics: $($_.Exception.Message)"
        exit 2
    }
}

#endregion Main Execution
