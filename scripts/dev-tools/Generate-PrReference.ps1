<#
.SYNOPSIS
Generates the Copilot PR reference XML using git history and diff data.

.DESCRIPTION
Creates .copilot-tracking/pr/pr-reference.xml relative to the repository root,
mirroring the behaviour of scripts/pr-ref-gen.sh. Supports excluding markdown
files from the diff and specifying an alternate base branch for comparisons.

.PARAMETER BaseBranch
Git branch used as the comparison base. Defaults to "main".

.PARAMETER ExcludeMarkdownDiff
When supplied, excludes markdown (*.md) files from the diff output.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$BaseBranch = "main",

    [Parameter()]
    [switch]$ExcludeMarkdownDiff
)

$ErrorActionPreference = 'Stop'

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

function Get-RepositoryRoot {
<#
.SYNOPSIS
Gets the repository root path.
.DESCRIPTION
Runs git rev-parse --show-toplevel and throws when the command fails.
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param()

    $repoRoot = (& git rev-parse --show-toplevel).Trim()
    if (-not $repoRoot) {
        throw "Unable to determine repository root."
    }

    return $repoRoot
}

function New-PrDirectory {
<#
.SYNOPSIS
Creates the PR tracking directory when missing.
.DESCRIPTION
Ensures .copilot-tracking/pr exists beneath the supplied repository root.
.PARAMETER RepoRoot
Absolute path to the git repository root.
.OUTPUTS
System.String
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $prDirectory = Join-Path $RepoRoot '.copilot-tracking/pr'
    if (-not (Test-Path $prDirectory)) {
        if ($PSCmdlet.ShouldProcess($prDirectory, 'Create PR tracking directory')) {
            $null = New-Item -ItemType Directory -Path $prDirectory -Force
        }
    }

    return $prDirectory
}

function Resolve-ComparisonReference {
<#
.SYNOPSIS
Resolves the git reference used for comparisons.
.DESCRIPTION
Prefers origin/<BaseBranch> when available and falls back to the provided branch.
.PARAMETER BaseBranch
Branch name supplied by the caller.
.OUTPUTS
PSCustomObject
#>
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseBranch
    )

    $candidates = @()
    if ($BaseBranch -notlike 'origin/*' -and $BaseBranch -notlike 'refs/*') {
        $candidates += "origin/$BaseBranch"
    }
    $candidates += $BaseBranch

    foreach ($candidate in $candidates) {
        & git rev-parse --verify $candidate *> $null
        if ($LASTEXITCODE -eq 0) {
            $label = if ($candidate -eq $BaseBranch) {
                $BaseBranch
            } else {
                "$BaseBranch (via $candidate)"
            }

            return [PSCustomObject]@{
                Ref   = $candidate
                Label = $label
            }
        }
    }

    throw "Branch '$BaseBranch' does not exist or is not accessible."
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
Runs git diff against the comparison ref with optional markdown exclusion.
.PARAMETER ComparisonRef
Git reference that acts as the diff base.
.PARAMETER ExcludeMarkdownDiff
Switch to omit markdown files from the diff.
.OUTPUTS
System.String[]
#>
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComparisonRef,

        [Parameter()]
        [switch]$ExcludeMarkdownDiff
    )

    $diffArgs = @('--no-pager', 'diff', $ComparisonRef)
    if ($ExcludeMarkdownDiff) {
        $diffArgs += @('--', ':!*.md')
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
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComparisonRef,

        [Parameter()]
        [switch]$ExcludeMarkdownDiff
    )

    $diffStatArgs = @('--no-pager', 'diff', '--shortstat', $ComparisonRef)
    if ($ExcludeMarkdownDiff) {
        $diffStatArgs += @('--', ':!*.md')
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
Branch used as the comparison base.
.PARAMETER ExcludeMarkdownDiff
Switch to omit markdown files from the diff and summary.
.OUTPUTS
System.IO.FileInfo
#>
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseBranch,

        [Parameter()]
        [switch]$ExcludeMarkdownDiff
    )

    Test-GitAvailability

    $repoRoot = Get-RepositoryRoot
    $prDirectory = New-PrDirectory -RepoRoot $repoRoot
    $prReferencePath = Join-Path $prDirectory 'pr-reference.xml'

    $diffSummary = '0 files changed'
    $commitCount = 0
    $comparisonInfo = $null
    $baseCommit = ''

    Push-Location $repoRoot
    try {
        $currentBranch = Get-CurrentBranchOrRef
        $comparisonInfo = Resolve-ComparisonReference -BaseBranch $BaseBranch
        $baseCommit = Get-ShortCommitHash -Ref $comparisonInfo.Ref
    $commitEntries = Get-CommitEntry -ComparisonRef $comparisonInfo.Ref
        $commitCount = Get-CommitCount -ComparisonRef $comparisonInfo.Ref
        $diffOutput = Get-DiffOutput -ComparisonRef $comparisonInfo.Ref -ExcludeMarkdownDiff:$ExcludeMarkdownDiff
        $diffSummary = Get-DiffSummary -ComparisonRef $comparisonInfo.Ref -ExcludeMarkdownDiff:$ExcludeMarkdownDiff

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
try {
    # Execute only when run directly, not when dot-sourced for testing
    if ($MyInvocation.InvocationName -ne '.') {
        Invoke-PrReferenceGeneration -BaseBranch $BaseBranch -ExcludeMarkdownDiff:$ExcludeMarkdownDiff | Out-Null
        exit 0
    }
}
catch {
    Write-Error "Generate PR Reference failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion
