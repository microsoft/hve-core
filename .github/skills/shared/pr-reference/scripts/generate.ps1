# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
Generates the Copilot PR reference XML using git history and diff data.

.DESCRIPTION
Creates a pr-reference.xml file (default: .copilot-tracking/pr/pr-reference.xml)
relative to the repository root, mirroring the behaviour of generate.sh. Supports
excluding markdown files from the diff and specifying an alternate base branch
for comparisons.

.PARAMETER BaseBranch
Git branch used as the comparison base. Defaults to "main".
Use "auto" to detect the remote default branch.

.PARAMETER MergeBase
When supplied, uses git merge-base for three-way comparison instead of
direct diff against the base branch.

.PARAMETER ExcludeMarkdownDiff
When supplied, excludes markdown (*.md) files from the diff output.

.PARAMETER ExcludeExt
Comma-separated or array of file extensions to exclude from the diff
(e.g., 'yml,yaml,json'). Leading dots are stripped automatically.

.PARAMETER ExcludePath
Comma-separated or array of path prefixes to exclude from the diff
(e.g., 'docs/,.github/skills/').

.PARAMETER OutputPath
Custom output file path. When empty, defaults to
.copilot-tracking/pr/pr-reference.xml relative to the repository root.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$BaseBranch = "main",

    [Parameter()]
    [switch]$MergeBase,

    [Parameter()]
    [switch]$ExcludeMarkdownDiff,

    [Parameter()]
    [string[]]$ExcludeExt = @(),

    [Parameter()]
    [string[]]$ExcludePath = @(),

    [Parameter()]
    [string]$OutputPath = ""
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'shared.psm1') -Force

function Test-GitAvailability {
<#
.SYNOPSIS
Verifies the git executable is available.
.DESCRIPTION
Throws a terminating error when git can't be resolved from PATH.
#>
    [OutputType([void])]
    param()

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is required but was not found on PATH."
    }
}

function New-PrDirectory {
<#
.SYNOPSIS
Creates the parent directory for the output file when missing.
.DESCRIPTION
Ensures the parent directory of the specified path exists.
.PARAMETER OutputFilePath
Absolute path to the output file whose parent directory should be created.
.OUTPUTS
System.String
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputFilePath
    )

    $parentDir = Split-Path -Parent $OutputFilePath
    if (-not (Test-Path $parentDir)) {
        if ($PSCmdlet.ShouldProcess($parentDir, 'Create output directory')) {
            $null = New-Item -ItemType Directory -Path $parentDir -Force
        }
    }

    return $parentDir
}

function Resolve-ComparisonReference {
<#
.SYNOPSIS
Resolves the git reference used for comparisons.
.DESCRIPTION
Prefers origin/<BaseBranch> when available and falls back to the provided branch.
When UseMergeBase is set, resolves the merge-base between HEAD and the branch.
.PARAMETER BaseBranch
Branch name supplied by the caller.
.PARAMETER UseMergeBase
When set, resolves the merge-base commit instead of using the branch directly.
.OUTPUTS
PSCustomObject
#>
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseBranch,

        [Parameter()]
        [switch]$UseMergeBase
    )

    $candidates = @()
    if ($BaseBranch -notlike 'origin/*' -and $BaseBranch -notlike 'refs/*') {
        $candidates += "origin/$BaseBranch"
    }
    $candidates += $BaseBranch

    $resolvedRef = $null
    $resolvedCandidate = $null
    foreach ($candidate in $candidates) {
        & git rev-parse --verify $candidate *> $null
        if ($LASTEXITCODE -eq 0) {
            $resolvedRef = $candidate
            $resolvedCandidate = $candidate
            break
        }
    }

    if (-not $resolvedRef) {
        throw "Branch '$BaseBranch' does not exist or is not accessible."
    }

    if ($UseMergeBase) {
        $mb = (& git merge-base HEAD $resolvedRef 2>$null)
        if ($LASTEXITCODE -eq 0 -and $mb) {
            $resolvedRef = $mb.Trim()
        } else {
            Write-Warning "merge-base resolution failed, using direct comparison"
        }
    }

    $label = if ($resolvedCandidate -eq $BaseBranch) {
        $BaseBranch
    } else {
        "$BaseBranch (via $resolvedCandidate)"
    }

    return [PSCustomObject]@{
        Ref   = $resolvedRef
        Label = $label
    }
}

function Get-ShortCommitHash {
<#
.SYNOPSIS
Retrieves the short commit hash for a ref.
.DESCRIPTION
Uses git rev-parse --short to resolve the supplied ref.
.PARAMETER Ref
Git reference to resolve.
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Ref
    )

    $commit = (& git rev-parse --short $Ref).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to resolve ref '$Ref'."
    }

    return $commit
}

function Get-CurrentBranchOrRef {
<#
.SYNOPSIS
Retrieves the current branch name or a fallback reference.
.DESCRIPTION
Returns the current branch name when on a branch. In detached HEAD state
(common in CI environments), falls back to a short commit SHA prefixed with
'detached@'.
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param()

    $branchOutput = & git --no-pager branch --show-current 2>$null
    if ($branchOutput) {
        return $branchOutput.Trim()
    }

    # Detached HEAD - fall back to short SHA
    $sha = (& git rev-parse --short HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $sha) {
        return "detached@$($sha.Trim())"
    }

    return 'unknown'
}

function Get-CommitEntry {
<#
.SYNOPSIS
Collects formatted commit metadata.
.DESCRIPTION
Runs git log to gather commit entries relative to the supplied comparison ref.
.PARAMETER ComparisonRef
Git reference that acts as the diff base.
.OUTPUTS
System.String[]
#>
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComparisonRef
    )

    $logArgs = @(
        '--no-pager',
        'log',
        '--pretty=format:<commit hash="%h" date="%cd"><message><subject><![CDATA[%s]]></subject><body><![CDATA[%b]]></body></message></commit>',
        '--date=short',
        "${ComparisonRef}..HEAD"
    )

    $entries = & git @logArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve commit history."
    }

    return $entries
}

function Get-CommitCount {
<#
.SYNOPSIS
Counts commits between HEAD and the comparison ref.
.DESCRIPTION
Executes git rev-list --count to measure branch divergence.
.PARAMETER ComparisonRef
Git reference that acts as the diff base.
.OUTPUTS
System.Int32
#>
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComparisonRef
    )

    $countText = (& git --no-pager rev-list --count "${ComparisonRef}..HEAD").Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to count commits."
    }

    if (-not $countText) {
        return 0
    }

    return [int]$countText
}

function Get-DiffOutput {
<#
.SYNOPSIS
Builds the git diff output for the comparison ref.
.DESCRIPTION
Runs git diff against the comparison ref with optional file exclusions.
.PARAMETER ComparisonRef
Git reference that acts as the diff base.
.PARAMETER ExcludeMarkdownDiff
Switch to omit markdown files from the diff.
.PARAMETER ExcludeExt
File extensions to exclude from the diff.
.PARAMETER ExcludePath
Path prefixes to exclude from the diff.
.OUTPUTS
System.String[]
#>
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComparisonRef,

        [Parameter()]
        [switch]$ExcludeMarkdownDiff,

        [Parameter()]
        [string[]]$ExcludeExt = @(),

        [Parameter()]
        [string[]]$ExcludePath = @()
    )

    $diffArgs = @('--no-pager', 'diff', $ComparisonRef)

    $pathspecs = @()
    if ($ExcludeMarkdownDiff) {
        $pathspecs += ':!*.md'
    }
    $pathspecs += Build-PathspecExclusions -Extensions $ExcludeExt -Paths $ExcludePath
    if ($pathspecs.Count -gt 0) {
        $diffArgs += '--'
        $diffArgs += $pathspecs
    }

    $diffOutput = & git @diffArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve diff output."
    }

    return $diffOutput
}

function Get-DiffSummary {
<#
.SYNOPSIS
Summarizes the diff for quick reporting.
.DESCRIPTION
Uses git diff --shortstat against the comparison ref.
.PARAMETER ComparisonRef
Git reference that acts as the diff base.
.PARAMETER ExcludeMarkdownDiff
Switch to omit markdown files from the summary.
.PARAMETER ExcludeExt
File extensions to exclude from the summary.
.PARAMETER ExcludePath
Path prefixes to exclude from the summary.
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComparisonRef,

        [Parameter()]
        [switch]$ExcludeMarkdownDiff,

        [Parameter()]
        [string[]]$ExcludeExt = @(),

        [Parameter()]
        [string[]]$ExcludePath = @()
    )

    $diffStatArgs = @('--no-pager', 'diff', '--shortstat', $ComparisonRef)

    $pathspecs = @()
    if ($ExcludeMarkdownDiff) {
        $pathspecs += ':!*.md'
    }
    $pathspecs += Build-PathspecExclusions -Extensions $ExcludeExt -Paths $ExcludePath
    if ($pathspecs.Count -gt 0) {
        $diffStatArgs += '--'
        $diffStatArgs += $pathspecs
    }

    $summary = & git @diffStatArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to summarize diff output."
    }

    if (-not $summary) {
        return '0 files changed'
    }

    return $summary
}

function Get-PrXmlContent {
<#
.SYNOPSIS
Constructs the PR reference XML document.
.DESCRIPTION
Creates XML containing the current branch, base branch, commits, and diff.
.PARAMETER CurrentBranch
Name of the active git branch.
.PARAMETER BaseBranch
Branch used as the base reference.
.PARAMETER CommitEntries
Formatted commit entries produced by Get-CommitEntry.
.PARAMETER DiffOutput
Diff lines produced by Get-DiffOutput.
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentBranch,

        [Parameter(Mandatory = $true)]
        [string]$BaseBranch,

        [Parameter()]
        [string[]]$CommitEntries,

        [Parameter()]
        [string[]]$DiffOutput
    )

    $commitBlock = if ($CommitEntries) {
        ($CommitEntries | ForEach-Object { "  $_" }) -join [Environment]::NewLine
    } else {
        ""
    }

    $diffBlock = if ($DiffOutput) {
        ($DiffOutput | ForEach-Object { "  $_" }) -join [Environment]::NewLine
    } else {
        ""
    }

    return @"
<commit_history>
  <current_branch>
    $CurrentBranch
  </current_branch>

  <base_branch>
    $BaseBranch
  </base_branch>

  <commits>
$commitBlock
  </commits>

  <full_diff>
$diffBlock
  </full_diff>
</commit_history>
"@
}

function Get-LineImpact {
<#
.SYNOPSIS
Calculates total line impact from a diff summary.
.DESCRIPTION
Parses insertion and deletion counts from git diff --shortstat output.
.PARAMETER DiffSummary
Short diff summary text.
.OUTPUTS
System.Int32
#>
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DiffSummary
    )

    $lineImpact = 0
    if ($DiffSummary -match '(\d+) insertions') {
        $lineImpact += [int]$matches[1]
    }
    if ($DiffSummary -match '(\d+) deletions') {
        $lineImpact += [int]$matches[1]
    }

    return $lineImpact
}

function Invoke-PrReferenceGeneration {
<#
.SYNOPSIS
Generates the pr-reference.xml file.
.DESCRIPTION
Coordinates git queries, XML creation, and console reporting for Copilot usage.
.PARAMETER BaseBranch
Branch used as the comparison base. Use 'auto' to detect the remote default.
.PARAMETER MergeBase
When supplied, uses git merge-base for three-way comparison.
.PARAMETER ExcludeMarkdownDiff
Switch to omit markdown files from the diff and summary.
.PARAMETER ExcludeExt
File extensions to exclude from the diff.
.PARAMETER ExcludePath
Path prefixes to exclude from the diff.
.PARAMETER OutputPath
Custom output file path. When empty, defaults to
.copilot-tracking/pr/pr-reference.xml relative to the repository root.
.OUTPUTS
System.IO.FileInfo
#>
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseBranch,

        [Parameter()]
        [switch]$MergeBase,

        [Parameter()]
        [switch]$ExcludeMarkdownDiff,

        [Parameter()]
        [string[]]$ExcludeExt = @(),

        [Parameter()]
        [string[]]$ExcludePath = @(),

        [Parameter()]
        [string]$OutputPath = ""
    )

    Test-GitAvailability

    $repoRoot = Get-RepositoryRoot -Strict

    # Resolve auto base branch
    if ($BaseBranch -eq 'auto') {
        $BaseBranch = Resolve-DefaultBranch
    }

    if ($OutputPath) {
        $prReferencePath = $OutputPath
    } else {
        $prReferencePath = Join-Path $repoRoot '.copilot-tracking/pr/pr-reference.xml'
    }

    $null = New-PrDirectory -OutputFilePath $prReferencePath

    $diffSummary = '0 files changed'
    $commitCount = 0
    $comparisonInfo = $null
    $baseCommit = ''

    Push-Location $repoRoot
    try {
        $currentBranch = Get-CurrentBranchOrRef
        $comparisonInfo = Resolve-ComparisonReference -BaseBranch $BaseBranch -UseMergeBase:$MergeBase
        $baseCommit = Get-ShortCommitHash -Ref $comparisonInfo.Ref
        $commitEntries = Get-CommitEntry -ComparisonRef $comparisonInfo.Ref
        $commitCount = Get-CommitCount -ComparisonRef $comparisonInfo.Ref
        $diffOutput = Get-DiffOutput -ComparisonRef $comparisonInfo.Ref -ExcludeMarkdownDiff:$ExcludeMarkdownDiff -ExcludeExt $ExcludeExt -ExcludePath $ExcludePath
        $diffSummary = Get-DiffSummary -ComparisonRef $comparisonInfo.Ref -ExcludeMarkdownDiff:$ExcludeMarkdownDiff -ExcludeExt $ExcludeExt -ExcludePath $ExcludePath

        $xmlContent = Get-PrXmlContent -CurrentBranch $currentBranch -BaseBranch $BaseBranch -CommitEntries $commitEntries -DiffOutput $diffOutput
        $xmlContent | Set-Content -LiteralPath $prReferencePath
    }
    finally {
        Pop-Location
    }

    $lineCount = (Get-Content -LiteralPath $prReferencePath).Count
    $lineImpact = Get-LineImpact -DiffSummary $diffSummary

    Write-Host "Created $prReferencePath"
    if ($ExcludeMarkdownDiff) {
        Write-Host 'Note: Markdown files were excluded from diff output'
    }
    if ($ExcludeExt.Count -gt 0) {
        Write-Host "Note: Extensions excluded from diff: $($ExcludeExt -join ', ')"
    }
    if ($ExcludePath.Count -gt 0) {
        Write-Host "Note: Paths excluded from diff: $($ExcludePath -join ', ')"
    }
    if ($MergeBase) {
        Write-Host 'Comparison mode: merge-base'
    }
    Write-Host "Lines: $lineCount"
    Write-Host "Base branch: $($comparisonInfo.Label) (@ $baseCommit)"
    Write-Host "Commits compared: $commitCount"
    Write-Host "Diff summary: $diffSummary"

    if ($lineImpact -gt 1000) {
        Write-Host 'Large diff detected. Rebase onto the intended base branch or narrow your changes if this scope is unexpected.'
    }

    return Get-Item -LiteralPath $prReferencePath
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-PrReferenceGeneration -BaseBranch $BaseBranch -MergeBase:$MergeBase -ExcludeMarkdownDiff:$ExcludeMarkdownDiff -ExcludeExt $ExcludeExt -ExcludePath $ExcludePath -OutputPath $OutputPath | Out-Null
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Generate PR Reference failed: $($_.Exception.Message)"
        Write-Warning "PR reference generation failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion
