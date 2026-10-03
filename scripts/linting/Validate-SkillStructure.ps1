# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# Validate-SkillStructure.ps1
#
# Purpose: Validates the structural integrity of skill directories under .github/skills/
# Author: HVE Core Team
#
# .PARAMETER OutputPath
# Output file path for validation results (default: logs/skill-validation-results.json)
#
# .PARAMETER SecurityClassificationPath
# Repository-relative path to the skill security classification file that declares exempt skills
# and pending security models (default: scripts/linting/skill-security-classification.json)
#
# .EXAMPLE
# pwsh -File scripts/linting/Validate-SkillStructure.ps1 -OutputPath "custom-dir/custom-results.json"

#Requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SkillsPath = '.github/skills',

    [Parameter(Mandatory = $false)]
    [switch]$WarningsAsErrors,

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = 'origin/main',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "logs/skill-validation-results.json",

    [Parameter(Mandatory = $false)]
    [string]$SecurityClassificationPath = 'scripts/linting/skill-security-classification.json'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force

# Recognized subdirectories within a skill directory
$script:RecognizedSubdirectories = @('scripts', 'references', 'assets', 'examples', 'tests', 'templates')

# Python environment directories excluded from unrecognized-subdirectory warnings in Python skills
$script:PythonEnvironmentDirs = @('.hypothesis', '.pytest_cache', '.ruff_cache', '.venv')

# Build artifact directories excluded from unrecognized-subdirectory warnings in any skill (always gitignored)
$script:BuildArtifactDirs = @('node_modules')

# Script extensions that count as shipped runtime when deciding whether a skill needs a security model
$script:SkillScriptExtensions = @('.ps1', '.psm1', '.sh', '.py', '.js', '.mjs', '.cjs', '.ts')

function Get-SkillFrontmatter {
    <#
    .SYNOPSIS
    Parses YAML frontmatter from a SKILL.md file.

    .DESCRIPTION
    Extracts single-line key-value pairs between --- delimiters using regex.
    Does not support multiline YAML scalars. Does not depend on the
    PowerShell-Yaml module.

    .PARAMETER Path
    Absolute path to the SKILL.md file.

    .OUTPUTS
    [hashtable] Parsed frontmatter key-value pairs, or $null if no frontmatter found.

    .EXAMPLE
    $fm = Get-SkillFrontmatter -Path '/repo/.github/skills/my-skill/SKILL.md'
    $fm['name']  # 'my-skill'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $content = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) {
        return $null
    }

    # Match frontmatter block between --- delimiters
    if ($content -notmatch '(?s)^---\r?\n(.+?)\r?\n---') {
        return $null
    }

    $frontmatterBlock = $Matches[1]
    $result = @{}

    # Split into lines and parse key-value pairs
    $lines = $frontmatterBlock -split '\r?\n'
    foreach ($line in $lines) {
        # Match key: value or key: 'value with spaces'
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()

            # Strip surrounding single or double quotes
            if (($value.StartsWith("'") -and $value.EndsWith("'")) -or
                ($value.StartsWith('"') -and $value.EndsWith('"'))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            $result[$key] = $value
        }
    }

    if ($result.Count -eq 0) {
        return $null
    }

    return $result
}

function Test-PythonSkillConfig {
    <#
    .SYNOPSIS
    Validates pyproject.toml contents for a Python skill.

    .DESCRIPTION
    Checks that pyproject.toml contains required TOML sections for ruff lint
    configuration and, when a tests/ directory exists, pytest configuration.

    .PARAMETER PyprojectPath
    Absolute path to the pyproject.toml file.

    .PARAMETER HasTestsDir
    Whether the skill directory contains a tests/ subdirectory.

    .PARAMETER RelativePath
    Relative skill path for error messages.

    .OUTPUTS
    [hashtable] With 'Errors' and 'Warnings' lists.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PyprojectPath,

        [Parameter(Mandatory = $true)]
        [bool]$HasTestsDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $content = Get-Content -Path $PyprojectPath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) {
        $errors.Add("pyproject.toml is empty in '$RelativePath'")
        return @{ Errors = $errors; Warnings = $warnings }
    }

    # Require [tool.ruff] section for lint:py compatibility
    if ($content -notmatch '\[tool\.ruff\]') {
        $errors.Add("pyproject.toml missing [tool.ruff] section in '$RelativePath' (required for lint:py)")
    }

    # Require [tool.ruff.lint] section for rule selection
    if ($content -notmatch '\[tool\.ruff\.lint\]') {
        $warnings.Add("pyproject.toml missing [tool.ruff.lint] section in '$RelativePath'")
    }

    # When tests/ exists, require pytest configuration
    if ($HasTestsDir) {
        if ($content -notmatch '\[tool\.pytest') {
            $errors.Add("pyproject.toml missing [tool.pytest.ini_options] section in '$RelativePath' (tests/ directory exists)")
        }

        # When tests/ exists, [tool.ruff.lint].select must include 'I' (isort)
        # so import-order regressions in test files cannot ship past lint:py.
        if ($content -match '\[tool\.ruff\.lint\][\s\S]*?select\s*=\s*\[([\s\S]*?)\]') {
            $selectArray = $Matches[1]
            if ($selectArray -notmatch '"I"|''I''') {
                $errors.Add("pyproject.toml [tool.ruff.lint].select must include 'I' (isort) in '$RelativePath' (tests/ directory exists)")
            }
        }
    }

    # Require ruff in dev dependencies (inline or multi-line TOML arrays)
    if ($content -notmatch '"ruff') {
        $warnings.Add("pyproject.toml does not list ruff in dev dependencies in '$RelativePath'")
    }

    # Warn when uv.lock is absent so Dependabot can resolve and patch dependencies
    $uvLockPath = Join-Path (Split-Path $PyprojectPath -Parent) 'uv.lock'
    if (-not (Test-Path $uvLockPath -PathType Leaf)) {
        $warnings.Add("pyproject.toml present without committed uv.lock in '$RelativePath' (required for Dependabot uv coverage)")
    }

    # Fuzz harness convention check
    if ($HasTestsDir) {
        $fuzzHarnessPath = Join-Path (Split-Path $PyprojectPath -Parent) 'tests' 'fuzz_harness.py'
        if (-not (Test-Path $fuzzHarnessPath -PathType Leaf)) {
            $errors.Add("$RelativePath - missing tests/fuzz_harness.py (fuzz harness convention for Scorecard compliance)")
        }
        else {
            # Fuzz harness exists — require companion pyproject.toml config
            if ($content -notmatch 'fuzz\s*=') {
                $errors.Add("$RelativePath pyproject.toml missing 'fuzz' dependency group (required for OSSF Scorecard Fuzzing)")
            }
            if ($content -notmatch 'fuzz_harness\.py') {
                $errors.Add("$RelativePath pyproject.toml python_files must include 'fuzz_harness.py' for pytest discovery")
            }
        }
    }

    return @{ Errors = $errors; Warnings = $warnings }
}

function Test-SecurityModelStructure {
    <#
    .SYNOPSIS
    Validates that a skill's SECURITY.md follows the canonical heading structure.

    .DESCRIPTION
    Enforces the per-skill STRIDE model layout defined in
    .github/instructions/skill-security-model.instructions.md: trust buckets are
    top-level '## Bucket Bn' sections (there is no '## Trust Buckets' umbrella),
    and each bucket's STRIDE categories and Risk Rating are '###' headings. Files
    that use the umbrella, H3 buckets, or H4 STRIDE/Risk Rating headings are
    flagged so the fleet cannot drift back to the deeper-nested variant.

    .PARAMETER Path
    Absolute path to the SECURITY.md file.

    .PARAMETER RelativePath
    Repository-relative path to the skill directory, used in messages.

    .OUTPUTS
    [string[]] Conformance errors (empty when the file conforms).

    .EXAMPLE
    $errs = Test-SecurityModelStructure -Path '/repo/.github/skills/jira/jira/SECURITY.md' -RelativePath 'jira/jira'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $lines = @(Get-Content -Path $Path -ErrorAction SilentlyContinue)
    if ($lines.Count -eq 0) {
        return [string[]]@()
    }

    $strideCategories = 'Spoofing|Tampering|Repudiation|Information Disclosure|Denial of Service|Elevation of Privilege|Risk Rating'

    if (@($lines | Where-Object { $_ -match '^## Trust Buckets\s*$' }).Count -gt 0) {
        $errors.Add("SECURITY.md uses the deprecated '## Trust Buckets' umbrella heading in '$RelativePath'; trust buckets must be top-level '## Bucket Bn' sections (see .github/instructions/skill-security-model.instructions.md)")
    }

    if (@($lines | Where-Object { $_ -match '^### Bucket B' }).Count -gt 0) {
        $errors.Add("SECURITY.md places trust buckets at H3 '### Bucket Bn' in '$RelativePath'; buckets must be H2 '## Bucket Bn'")
    }

    if (@($lines | Where-Object { $_ -match "^#### ($strideCategories)\s*`$" }).Count -gt 0) {
        $errors.Add("SECURITY.md places STRIDE or Risk Rating headings at H4 in '$RelativePath'; they must be H3 '### <Category>'")
    }

    return [string[]]$errors.ToArray()
}

function Get-SkillScriptFile {
    <#
    .SYNOPSIS
    Lists the shipped, non-test script files in a skill directory.

    .DESCRIPTION
    Returns files with a script extension anywhere in the skill, excluding files
    under a tests/ directory, *.test.* and *.spec.* files, and installed
    dependency or environment trees. These are the files the skill security
    model rule evaluates.

    .PARAMETER Directory
    DirectoryInfo object for the skill directory.

    .OUTPUTS
    [System.IO.FileInfo[]] Shipped non-test script files.

    .EXAMPLE
    $scripts = Get-SkillScriptFile -Directory (Get-Item '.github/skills/rpi/rpi-plan')
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory
    )

    $files = Get-ChildItem -LiteralPath $Directory.FullName -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $relative = [System.IO.Path]::GetRelativePath($Directory.FullName, $_.FullName) -replace '\\', '/'
            $_.Extension -in $script:SkillScriptExtensions -and
            $relative -notmatch '(^|/)tests/' -and
            $_.Name -notmatch '\.(test|spec)\.' -and
            $relative -notmatch '(^|/)(node_modules|\.venv|__pycache__)/'
        }
    return [System.IO.FileInfo[]]@($files)
}

function Get-SkillSecurityClassification {
    <#
    .SYNOPSIS
    Loads and validates the skill security classification file.

    .DESCRIPTION
    Requires strictly valid JSON with schemaVersion 1 and a skills object whose
    entries are either exempt with a non-empty reason or pending with a positive
    integer issue number. Returns the valid entries keyed by skill path relative
    to the skills root, plus every file-level error.

    .PARAMETER Path
    Absolute path to the classification file.

    .OUTPUTS
    [PSCustomObject] With Skills (hashtable) and Errors (string[]).

    .EXAMPLE
    $classification = Get-SkillSecurityClassification -Path '/repo/scripts/linting/skill-security-classification.json'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $skills = @{}
    $fileName = Split-Path -Leaf $Path

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $errors.Add("Skill security classification file not found at '$Path'")
        return [PSCustomObject]@{ Skills = $skills; Errors = [string[]]$errors.ToArray() }
    }

    $text = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    # System.Text.Json rejects comments, trailing commas, and other input that ConvertFrom-Json tolerates.
    try {
        $document = [System.Text.Json.JsonDocument]::Parse($text)
        $document.Dispose()
    }
    catch {
        $errors.Add("$fileName is not strictly valid JSON: $($_.Exception.Message)")
        return [PSCustomObject]@{ Skills = $skills; Errors = [string[]]$errors.ToArray() }
    }

    $data = $text | ConvertFrom-Json -AsHashtable
    if ($data -isnot [System.Collections.IDictionary]) {
        $errors.Add("$fileName must contain a JSON object")
        return [PSCustomObject]@{ Skills = $skills; Errors = [string[]]$errors.ToArray() }
    }

    $schemaVersion = $data['schemaVersion']
    if (-not (($schemaVersion -is [int] -or $schemaVersion -is [long]) -and $schemaVersion -eq 1)) {
        $errors.Add("$fileName schemaVersion must be the integer 1")
    }

    if ($data['skills'] -isnot [System.Collections.IDictionary]) {
        $errors.Add("$fileName must contain a 'skills' object")
        return [PSCustomObject]@{ Skills = $skills; Errors = [string[]]$errors.ToArray() }
    }

    foreach ($key in $data['skills'].Keys) {
        $entry = $data['skills'][$key]
        if ($entry -isnot [System.Collections.IDictionary]) {
            $errors.Add("$fileName entry '$key' must be an object")
            continue
        }
        $status = $entry['status']
        if ($status -eq 'exempt') {
            if ($entry['reason'] -isnot [string] -or [string]::IsNullOrWhiteSpace($entry['reason'])) {
                $errors.Add("$fileName entry '$key' is exempt but has no reason")
                continue
            }
        }
        elseif ($status -eq 'pending') {
            $issue = $entry['issue']
            if (-not (($issue -is [int] -or $issue -is [long]) -and $issue -gt 0)) {
                $errors.Add("$fileName entry '$key' is pending but has no positive integer issue number")
                continue
            }
        }
        else {
            $errors.Add("$fileName entry '$key' has status '$status'; expected 'exempt' or 'pending'")
            continue
        }
        $skills[[string]$key] = $entry
    }

    return [PSCustomObject]@{ Skills = $skills; Errors = [string[]]$errors.ToArray() }
}

function Test-SkillSecurityClassification {
    <#
    .SYNOPSIS
    Checks one skill against the skill security classification.

    .DESCRIPTION
    A skill that ships non-test scripts must have a SECURITY.md or a
    classification entry. A skill that has a SECURITY.md must not also carry an
    entry, so the classification cannot go stale after a model is added.

    .PARAMETER Directory
    DirectoryInfo object for the skill directory.

    .PARAMETER SkillKey
    Skill path relative to the skills root, using forward slashes.

    .PARAMETER Classification
    Valid classification entries keyed by skill path.

    .PARAMETER RelativePath
    Repository-relative path to the skill directory, used in messages.

    .OUTPUTS
    [string[]] Classification errors (empty when the skill conforms).

    .EXAMPLE
    $errs = Test-SkillSecurityClassification -Directory $dir -SkillKey 'rpi/rpi-plan' -Classification $entries -RelativePath '.github/skills/rpi/rpi-plan'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SkillKey,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable]$Classification,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $hasModel = Test-Path -LiteralPath (Join-Path $Directory.FullName 'SECURITY.md') -PathType Leaf
    $hasEntry = $Classification.ContainsKey($SkillKey)

    if ($hasModel -and $hasEntry) {
        $errors.Add("'$RelativePath' has a SECURITY.md but is still listed as '$($Classification[$SkillKey]['status'])' in the skill security classification; remove the entry")
    }
    elseif (-not $hasModel -and -not $hasEntry -and @(Get-SkillScriptFile -Directory $Directory).Count -gt 0) {
        $errors.Add("'$RelativePath' ships scripts but has neither a SECURITY.md nor a skill security classification entry; classify it under the skill security model conventions")
    }

    return [string[]]$errors.ToArray()
}

function Get-SkillClassificationCoverageError {
    <#
    .SYNOPSIS
    Checks skill security classification coverage across every skill directory.

    .DESCRIPTION
    Runs Test-SkillSecurityClassification for each skill directory under the
    skills root, skipping directories that were already validated in this run
    and installed dependency or virtual-environment trees. Changed-files-only
    validation uses this so a classification change cannot pass by leaving
    unchanged skills unchecked.

    .PARAMETER SkillsRoot
    Absolute path to the skills root directory.

    .PARAMETER Classification
    Valid classification entries keyed by skill path.

    .PARAMETER RepoRoot
    Repository root used to build repository-relative paths in messages.

    .PARAMETER ExcludeDirectory
    Full paths of skill directories already validated in this run.

    .OUTPUTS
    [string[]] Classification coverage errors (empty when every skill conforms).

    .EXAMPLE
    $errs = Get-SkillClassificationCoverageError -SkillsRoot '/repo/.github/skills' -Classification $entries -RepoRoot '/repo'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SkillsRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable]$Classification,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$ExcludeDirectory = @()
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $SkillsRoot -PathType Container)) {
        return [string[]]$errors.ToArray()
    }

    $skillFiles = Get-ChildItem -LiteralPath $SkillsRoot -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.venv)[\\/]' }
    foreach ($skillFile in $skillFiles) {
        $directory = $skillFile.Directory
        if ($directory.FullName -in $ExcludeDirectory) {
            continue
        }
        $skillKey = [System.IO.Path]::GetRelativePath($SkillsRoot, $directory.FullName) -replace '\\', '/'
        $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $directory.FullName) -replace '\\', '/'
        foreach ($err in (Test-SkillSecurityClassification -Directory $directory -SkillKey $skillKey `
                    -Classification $Classification -RelativePath $relativePath)) {
            $errors.Add($err)
        }
    }

    return [string[]]$errors.ToArray()
}

function Test-NodeSkillConfig {
    <#
    .SYNOPSIS
    Validates Node unit-test coverage for a skill that ships JS-family modules.

    .DESCRIPTION
    When a skill contains non-test .mjs/.cjs/.js files under scripts/, requires
    at least one *.test.* or *.spec.* (mjs/cjs/js) unit test so shipped Node
    logic is tested. This mirrors the Python tests/ + pytest requirement and the
    node-tests CI job + Codecov 'node' flag, keeping Node skills at parity with
    Python skills.

    .PARAMETER SkillPath
    Absolute path to the skill directory.

    .PARAMETER RelativePath
    Relative skill path for messages.

    .OUTPUTS
    [hashtable] With 'Errors' and 'Warnings' lists.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SkillPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $scriptsDir = Join-Path -Path $SkillPath -ChildPath 'scripts'
    if (-not (Test-Path $scriptsDir -PathType Container)) {
        return @{ Errors = $errors; Warnings = $warnings }
    }

    # Non-test .mjs/.cjs/.js modules under scripts/ are shippable Node logic.
    $sourceModules = @(Get-ChildItem -Path $scriptsDir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @('.mjs', '.cjs', '.js') -and
            $_.Name -notmatch '\.(test|spec)\.(mjs|cjs|js)$' -and
            $_.FullName -notmatch 'node_modules'
        })
    if ($sourceModules.Count -eq 0) {
        return @{ Errors = $errors; Warnings = $warnings }
    }

    # Test files follow the *.test.* / *.spec.* convention across the JS family.
    $testModules = @(Get-ChildItem -Path $SkillPath -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '\.(test|spec)\.(mjs|cjs|js)$' -and $_.FullName -notmatch 'node_modules' })

    if ($testModules.Count -eq 0) {
        $errors.Add("$RelativePath ships Node modules (scripts/**/*.{mjs,cjs,js}) but has no *.test.* / *.spec.* unit tests (required for 'node --test' + Codecov 'node' flag parity)")
    }
    else {
        $underTestsDir = @($testModules | Where-Object { ($_.FullName -replace '\\', '/') -match '/tests/' })
        if ($underTestsDir.Count -eq 0) {
            $warnings.Add("$RelativePath - test modules should live under a tests/ directory for 'node --test' discovery")
        }
    }

    return @{ Errors = $errors; Warnings = $warnings }
}

function Test-SkillDirectory {
    <#
    .SYNOPSIS
    Validates a single skill directory for structural compliance.

    .DESCRIPTION
    Checks that a skill directory contains a SKILL.md with valid frontmatter,
    required fields, name consistency, and recognized subdirectories.

    .PARAMETER Directory
    DirectoryInfo object for the skill directory to validate.

    .PARAMETER RepoRoot
    Repository root path for computing relative paths.

    .PARAMETER SecurityClassification
    Optional valid skill security classification entries keyed by skill path.
    When supplied, the skill is checked against the classification.

    .PARAMETER SkillsRoot
    Absolute skills root used to derive the classification key. Required when
    SecurityClassification is supplied.

    .OUTPUTS
    [PSCustomObject] Validation result with SkillName, SkillPath, IsValid, Errors, and Warnings.

    .EXAMPLE
    $dir = Get-Item '.github/skills/video-to-gif'
    $result = Test-SkillDirectory -Directory $dir -RepoRoot '/repo'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [hashtable]$SecurityClassification,

        [Parameter(Mandatory = $false)]
        [string]$SkillsRoot
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $skillName = $Directory.Name
    $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $Directory.FullName) -replace '\\', '/'

    # Check SKILL.md exists
    $skillMdPath = Join-Path -Path $Directory.FullName -ChildPath 'SKILL.md'
    if (-not (Test-Path $skillMdPath)) {
        $errors.Add("SKILL.md is missing from '$relativePath'")
        return [PSCustomObject]@{
            SkillName = $skillName
            SkillPath = $relativePath
            IsValid   = $false
            Errors    = [string[]]$errors.ToArray()
            Warnings  = [string[]]$warnings.ToArray()
        }
    }

    # Parse frontmatter
    $frontmatter = Get-SkillFrontmatter -Path $skillMdPath
    if ($null -eq $frontmatter) {
        $errors.Add("SKILL.md has missing or malformed frontmatter in '$relativePath'")
        return [PSCustomObject]@{
            SkillName = $skillName
            SkillPath = $relativePath
            IsValid   = $false
            Errors    = [string[]]$errors.ToArray()
            Warnings  = [string[]]$warnings.ToArray()
        }
    }

    # Required frontmatter fields
    if (-not $frontmatter.ContainsKey('name') -or [string]::IsNullOrWhiteSpace($frontmatter['name'])) {
        $errors.Add("SKILL.md frontmatter missing required 'name' field in '$relativePath'")
    }

    if (-not $frontmatter.ContainsKey('description') -or [string]::IsNullOrWhiteSpace($frontmatter['description'])) {
        $errors.Add("SKILL.md frontmatter missing required 'description' field in '$relativePath'")
    }

    # Name must match directory name
    if ($frontmatter.ContainsKey('name') -and -not [string]::IsNullOrWhiteSpace($frontmatter['name'])) {
        if ($frontmatter['name'] -ne $skillName) {
            $errors.Add("Frontmatter 'name' value '$($frontmatter['name'])' does not match directory name '$skillName'")
        }
    }

    # Detect Python skill by pyproject.toml presence
    $pyprojectPath = Join-Path -Path $Directory.FullName -ChildPath 'pyproject.toml'
    $isPythonSkill = Test-Path $pyprojectPath -PathType Leaf

    # Check scripts/ subdirectory contents
    $scriptsDirPath = Join-Path -Path $Directory.FullName -ChildPath 'scripts'
    if (Test-Path $scriptsDirPath -PathType Container) {
        $allScriptFiles = Get-ChildItem -Path $scriptsDirPath -File -ErrorAction SilentlyContinue
        $hasPowerShell = @($allScriptFiles | Where-Object { $_.Extension -eq '.ps1' }).Count -gt 0
        $hasBash = @($allScriptFiles | Where-Object { $_.Extension -eq '.sh' }).Count -gt 0
        # Python files may be packaged in subdirectories (e.g., scripts/<pkg>/__init__.py); search recursively.
        $hasPython = @(Get-ChildItem -Path $scriptsDirPath -File -Recurse -Filter '*.py' -ErrorAction SilentlyContinue).Count -gt 0
        # Node modules (.mjs/.cjs/.js, excluding *.test.*/*.spec.*) may be packaged in subdirectories; search recursively.
        $hasNode = @(Get-ChildItem -Path $scriptsDirPath -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.mjs', '.cjs', '.js') -and $_.Name -notmatch '\.(test|spec)\.(mjs|cjs|js)$' -and $_.FullName -notmatch 'node_modules' }).Count -gt 0

        if ($isPythonSkill) {
            # Python skills: require at least one .py, OR the traditional .ps1+.sh pair
            if (-not $hasPython -and -not ($hasPowerShell -and $hasBash)) {
                $errors.Add("'scripts/' subdirectory exists but contains no .py files and no .ps1/.sh pair in '$relativePath'")
            }
        }
        elseif ($hasNode) {
            # Node skills: .mjs modules are the entrypoints; test presence is
            # enforced separately by Test-NodeSkillConfig.
        }
        else {
            # Non-Python skills: require both .ps1 and .sh
            if (-not $hasPowerShell -and -not $hasBash) {
                $errors.Add("'scripts/' subdirectory exists but contains no .ps1 or .sh files in '$relativePath'")
            }
            elseif (-not $hasPowerShell) {
                $errors.Add("'scripts/' subdirectory is missing a required .ps1 file in '$relativePath'")
            }
            elseif (-not $hasBash) {
                $errors.Add("'scripts/' subdirectory is missing a required .sh file in '$relativePath'")
            }
        }
    }

    # Validate pyproject.toml contents for Python skills
    if ($isPythonSkill) {
        $testsDirPath = Join-Path -Path $Directory.FullName -ChildPath 'tests'
        $hasTestsDir = Test-Path $testsDirPath -PathType Container
        $pyResult = Test-PythonSkillConfig -PyprojectPath $pyprojectPath -HasTestsDir $hasTestsDir -RelativePath $relativePath
        foreach ($err in $pyResult.Errors) { $errors.Add($err) }
        foreach ($warn in $pyResult.Warnings) { $warnings.Add($warn) }
    }

    # Validate per-skill SECURITY.md heading structure when a model is present
    $securityMdPath = Join-Path -Path $Directory.FullName -ChildPath 'SECURITY.md'
    if (Test-Path $securityMdPath -PathType Leaf) {
        $secErrors = Test-SecurityModelStructure -Path $securityMdPath -RelativePath $relativePath
        foreach ($err in $secErrors) { $errors.Add($err) }
    }

    # Require a model or a classification entry for skills that ship scripts
    if ($null -ne $SecurityClassification -and -not [string]::IsNullOrEmpty($SkillsRoot)) {
        $skillKey = [System.IO.Path]::GetRelativePath($SkillsRoot, $Directory.FullName) -replace '\\', '/'
        $classificationErrors = Test-SkillSecurityClassification -Directory $Directory -SkillKey $skillKey `
            -Classification $SecurityClassification -RelativePath $relativePath
        foreach ($err in $classificationErrors) { $errors.Add($err) }
    }

    # Validate Node unit-test presence for skills that ship .mjs modules
    $nodeResult = Test-NodeSkillConfig -SkillPath $Directory.FullName -RelativePath $relativePath
    foreach ($err in $nodeResult.Errors) { $errors.Add($err) }
    foreach ($warn in $nodeResult.Warnings) { $warnings.Add($warn) }

    # Check for unrecognized subdirectories (-Force includes dot-prefixed dirs hidden on Linux)
    $subdirs = Get-ChildItem -Path $Directory.FullName -Directory -Force -ErrorAction SilentlyContinue
    foreach ($subdir in $subdirs) {
        if ($subdir.Name -notin $script:RecognizedSubdirectories) {
            # Python package directories (containing __init__.py) are valid in Python skills
            $initPyPath = Join-Path -Path $subdir.FullName -ChildPath '__init__.py'
            if ($isPythonSkill -and (Test-Path $initPyPath -PathType Leaf)) {
                continue
            }
            # Standard Python environment directories are expected in Python skills
            if ($isPythonSkill -and $subdir.Name -in $script:PythonEnvironmentDirs) {
                continue
            }
            # Build artifact directories (e.g. node_modules) are always gitignored and not skill content
            if ($subdir.Name -in $script:BuildArtifactDirs) {
                continue
            }
            $warnings.Add("Unrecognized subdirectory '$($subdir.Name)' in '$relativePath' (recognized: $($script:RecognizedSubdirectories -join ', '))")
        }
    }

    $isValid = $errors.Count -eq 0

    return [PSCustomObject]@{
        SkillName = $skillName
        SkillPath = $relativePath
        IsValid   = $isValid
        Errors    = [string[]]$errors.ToArray()
        Warnings  = [string[]]$warnings.ToArray()
    }
}

function Get-ChangedSkillDirectories {
    <#
    .SYNOPSIS
    Returns skill directory names that contain changed files.

    .DESCRIPTION
    Uses Get-ChangedFilesFromGit (LintingHelpers) to identify changed files
    under the skills path with merge-base, HEAD~1, and staged/unstaged
    fallbacks, then extracts unique skill directory names.

    .PARAMETER BaseBranch
    Git reference for the base branch comparison. Default: 'origin/main'.

    .PARAMETER SkillsPath
    Relative path to the skills directory. Default: '.github/skills'.

    .OUTPUTS
    [string[]] Unique skill directory names with changes.

    .EXAMPLE
    $changed = Get-ChangedSkillDirectories -BaseBranch 'origin/main'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseBranch = 'origin/main',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SkillsPath = '.github/skills'
    )

    $changedFiles = @(Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*'))

    # Normalize skills path for matching
    $normalizedSkillsPath = $SkillsPath -replace '\\', '/'
    if (-not $normalizedSkillsPath.EndsWith('/')) {
        $normalizedSkillsPath += '/'
    }

    $skillNames = @($changedFiles |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_ -replace '\\', '/' } |
        Where-Object { $_.StartsWith($normalizedSkillsPath) } |
        ForEach-Object {
            $remainder = $_.Substring($normalizedSkillsPath.Length)
            $parts = $remainder -split '/'
            if ($parts.Count -gt 0) { $parts[0] }
        } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique)

    return $skillNames
}

function Write-SkillValidationResults {
    <#
    .SYNOPSIS
    Outputs skill validation results to console and writes JSON to logs.

    .DESCRIPTION
    Displays per-skill pass/fail status with colored output, emits CI annotations
    when running in a CI environment, and exports results as JSON.

    .PARAMETER Results
    Array of validation result objects from Test-SkillDirectory.

    .PARAMETER RepoRoot
    Repository root path for resolving the logs directory.

    .PARAMETER OutputPath
    Output file path for validation results (default: logs/skill-validation-results.json)

    .EXAMPLE
    Write-SkillValidationResults -Results $results -RepoRoot '/repo' -OutputPath 'custom-dir/custom-results.json'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "logs/skill-validation-results.json"
    )

    $isCI = Test-CIEnvironment

    Write-Host "`nSkill Structure Validation Results" -ForegroundColor Cyan
    Write-Host ("-" * 40) -ForegroundColor Cyan

    foreach ($result in $Results) {
        if ($result.IsValid -and $result.Warnings.Count -eq 0) {
            Write-Host "  ✅ $($result.SkillName)" -ForegroundColor Green
        }
        elseif ($result.IsValid) {
            Write-Host "  ⚠️  $($result.SkillName) (warnings)" -ForegroundColor Yellow
        }
        else {
            Write-Host "  ❌ $($result.SkillName)" -ForegroundColor Red
        }

        foreach ($err in $result.Errors) {
            Write-Host "     ERROR: $err" -ForegroundColor Red
            if ($isCI) {
                $annotationFile = if ($result.SkillPath -like '*.json') { $result.SkillPath } else { "$($result.SkillPath)/SKILL.md" }
                Write-CIAnnotation -Message $err -Level Error -File $annotationFile
            }
        }
        foreach ($warn in $result.Warnings) {
            Write-Host "     WARNING: $warn" -ForegroundColor Yellow
            if ($isCI) {
                $skillMdRelative = "$($result.SkillPath)/SKILL.md"
                Write-CIAnnotation -Message $warn -Level Warning -File $skillMdRelative
            }
        }
    }

    # Summary
    $totalSkills = $Results.Count
    $errorCount = @($Results | Where-Object { -not $_.IsValid }).Count
    $warningCount = @($Results | Where-Object { $_.Warnings.Count -gt 0 }).Count

    Write-Host "`n📋 Summary:" -ForegroundColor Cyan
    Write-Host "   Total skills:    $totalSkills" -ForegroundColor Gray
    Write-Host "   With errors:     $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "   With warnings:   $warningCount" -ForegroundColor $(if ($warningCount -gt 0) { 'Yellow' } else { 'Green' })

    # Write JSON results
    $resolvedOutputPath = Join-Path -Path $RepoRoot -ChildPath $OutputPath
    $outputDir = Split-Path -Parent $resolvedOutputPath
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $jsonOutput = @{
        Timestamp    = Get-StandardTimestamp
        totalSkills  = $totalSkills
        skillErrors  = $errorCount
        skillWarnings = $warningCount
        results      = @($Results | ForEach-Object {
            @{
                skillName = $_.SkillName
                skillPath = $_.SkillPath
                isValid   = $_.IsValid
                errors    = @($_.Errors)
                warnings  = @($_.Warnings)
            }
        })
    }

    $jsonOutput | ConvertTo-Json -Depth 10 | Set-Content -Path $resolvedOutputPath -Encoding UTF8
    Write-Host "📊 Results written to: $resolvedOutputPath" -ForegroundColor Cyan
}

function Invoke-SkillStructureValidation {
    <#
    .SYNOPSIS
    Orchestrates skill structure validation and returns an exit code.

    .DESCRIPTION
    Resolves the repository root, discovers skill directories (optionally
    filtered to changed files), validates each one, writes results, and
    returns an integer exit code. Extracted from the main execution block
    for testability.

    .PARAMETER SkillsPath
    Relative path to the skills directory from the repo root.

    .PARAMETER WarningsAsErrors
    Treat warnings as errors for exit code calculation.

    .PARAMETER ChangedFilesOnly
    Validate only skill directories containing changed files.

    .PARAMETER BaseBranch
    Git reference for the base branch comparison when using ChangedFilesOnly.

    .PARAMETER OutputPath
    Output file path for validation results (default: logs/skill-validation-results.json)

    .PARAMETER SecurityClassificationPath
    Optional repository-relative path to the skill security classification file.
    When supplied, the file must exist and be valid, every entry must name an
    existing skill, and every skill that ships scripts must have a SECURITY.md
    or an entry. File-level errors and skill coverage are checked across the
    whole skills tree in both full and changed-files-only modes, so a
    classification change cannot pass by leaving unchanged skills unchecked.

    .OUTPUTS
    [int] Exit code: 0 for success, 1 for failure.

    .EXAMPLE
    $exitCode = Invoke-SkillStructureValidation -SkillsPath '.github/skills' -OutputPath 'custom-dir/custom-results.json'
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SkillsPath = '.github/skills',

        [Parameter(Mandatory = $false)]
        [switch]$WarningsAsErrors,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = 'origin/main',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "logs/skill-validation-results.json",

        [Parameter(Mandatory = $false)]
        [string]$SecurityClassificationPath = ''
    )

    try {
        # Resolve repo root
        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot -or $LASTEXITCODE -ne 0) {
            $repoRoot = (Get-Location).Path
        }

        $fullSkillsPath = Join-Path -Path $repoRoot -ChildPath $SkillsPath

        # Load the security classification first so file-level errors surface even when no skill changed
        $classificationEntries = $null
        $classificationErrors = [System.Collections.Generic.List[string]]::new()
        $classificationRelativePath = $null
        if (-not [string]::IsNullOrWhiteSpace($SecurityClassificationPath)) {
            $classificationFullPath = if ([System.IO.Path]::IsPathRooted($SecurityClassificationPath)) {
                $SecurityClassificationPath
            }
            else {
                Join-Path -Path $repoRoot -ChildPath $SecurityClassificationPath
            }
            $classificationRelativePath = [System.IO.Path]::GetRelativePath($repoRoot, $classificationFullPath) -replace '\\', '/'
            $classification = Get-SkillSecurityClassification -Path $classificationFullPath
            foreach ($err in $classification.Errors) { $classificationErrors.Add($err) }
            foreach ($key in $classification.Skills.Keys) {
                if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $fullSkillsPath $key) 'SKILL.md') -PathType Leaf)) {
                    $classificationErrors.Add("Skill security classification lists '$key', which is not a skill directory under '$SkillsPath'")
                }
            }
            if (Test-Path -LiteralPath $classificationFullPath -PathType Leaf) {
                $classificationEntries = $classification.Skills
            }
        }
        $resolvedSkillsRoot = [System.IO.Path]::GetFullPath($fullSkillsPath)

        if ($ChangedFilesOnly) {
            Write-Host "🔍 Detecting changed skill directories..." -ForegroundColor Cyan
            $changedSkills = @(Get-ChangedSkillDirectories -BaseBranch $BaseBranch -SkillsPath $SkillsPath)

            if ($changedSkills.Count -gt 0) {
                Write-Host "Found $($changedSkills.Count) changed skill path(s) to validate" -ForegroundColor Cyan
            }

            $results = @()
            $validatedDirs = @{}
            foreach ($skillRelPath in $changedSkills) {
                $candidatePath = Join-Path -Path $fullSkillsPath -ChildPath $skillRelPath
                if (-not (Test-Path $candidatePath -PathType Container)) {
                    Write-Host "  ⏭️  Skill '$skillRelPath' was deleted - skipping validation" -ForegroundColor DarkGray
                    continue
                }
                # Find SKILL.md files at or below the changed path (excluding
                # installed dependency and virtual-environment trees)
                $skillMdFiles = Get-ChildItem -Path $candidatePath -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.venv)[\\/]' }
                if ($null -eq $skillMdFiles -or @($skillMdFiles).Count -eq 0) {
                    # Check if the changed path is inside a skill directory (ancestor has SKILL.md)
                    $searchDir = Get-Item $candidatePath
                    while ($null -ne $searchDir -and $searchDir.FullName -ne $fullSkillsPath) {
                        $ancestorSkillMd = Join-Path -Path $searchDir.FullName -ChildPath 'SKILL.md'
                        if (Test-Path $ancestorSkillMd -PathType Leaf) {
                            $skillMdFiles = @(Get-Item $ancestorSkillMd)
                            break
                        }
                        $searchDir = $searchDir.Parent
                    }
                }
                foreach ($skillMdFile in $skillMdFiles) {
                    $dirKey = $skillMdFile.Directory.FullName
                    if (-not $validatedDirs.ContainsKey($dirKey)) {
                        $validatedDirs[$dirKey] = $true
                        $results += Test-SkillDirectory -Directory $skillMdFile.Directory -RepoRoot $repoRoot `
                            -SecurityClassification $classificationEntries -SkillsRoot $resolvedSkillsRoot
                    }
                }
            }

            # Changed collections may not include every classified skill, so check coverage for the rest
            if ($null -ne $classificationEntries) {
                $coverageErrors = Get-SkillClassificationCoverageError -SkillsRoot $resolvedSkillsRoot `
                    -Classification $classificationEntries -RepoRoot $repoRoot -ExcludeDirectory @($validatedDirs.Keys)
                foreach ($err in $coverageErrors) { $classificationErrors.Add($err) }
            }

            if ($results.Count -eq 0 -and $classificationErrors.Count -eq 0) {
                if ($changedSkills.Count -eq 0) {
                    Write-Host "✅ No changed skill directories found - validation complete" -ForegroundColor Green
                }
                else {
                    Write-Host "✅ No skill directories to validate after filtering - success" -ForegroundColor Green
                }
                return 0
            }
        }
        else {
            if (-not (Test-Path $fullSkillsPath -PathType Container)) {
                Write-Host "Skills directory not found at '$SkillsPath' - nothing to validate" -ForegroundColor Yellow
                return 0
            }

            $skillFiles = Get-ChildItem -Path $fullSkillsPath -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.venv)[\\/]' }
            if ($null -eq $skillFiles -or @($skillFiles).Count -eq 0) {
                Write-Host "No skill directories found under '$SkillsPath' - nothing to validate" -ForegroundColor Yellow
                return 0
            }

            Write-Host "🔍 Validating $(@($skillFiles).Count) skill directory(ies)..." -ForegroundColor Cyan

            $results = @()
            foreach ($skillFile in $skillFiles) {
                $results += Test-SkillDirectory -Directory $skillFile.Directory -RepoRoot $repoRoot `
                    -SecurityClassification $classificationEntries -SkillsRoot $resolvedSkillsRoot
            }
        }

        if ($classificationErrors.Count -gt 0) {
            $classificationResult = [PSCustomObject]@{
                SkillName = 'skill-security-classification'
                SkillPath = $classificationRelativePath
                IsValid   = $false
                Errors    = [string[]]$classificationErrors.ToArray()
                Warnings  = [string[]]@()
            }
            $results = @($classificationResult) + @($results)
        }

        Write-SkillValidationResults -Results $results -RepoRoot $repoRoot -OutputPath $OutputPath

        # Calculate exit code
        $hasErrors = @($results | Where-Object { -not $_.IsValid }).Count -gt 0
        $hasWarnings = @($results | Where-Object { $_.Warnings.Count -gt 0 }).Count -gt 0

        if ($hasErrors) {
            return 1
        }
        elseif ($WarningsAsErrors -and $hasWarnings) {
            return 1
        }
        else {
            Write-Host "✅ Skill structure validation complete" -ForegroundColor Green
            return 0
        }
    }
    catch {
        Write-Error -ErrorAction Continue "Validate-SkillStructure failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        return 1
    }
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-SkillStructureValidation `
        -SkillsPath $SkillsPath `
        -WarningsAsErrors:$WarningsAsErrors `
        -ChangedFilesOnly:$ChangedFilesOnly `
        -BaseBranch $BaseBranch `
        -OutputPath $OutputPath `
        -SecurityClassificationPath $SecurityClassificationPath
    exit $exitCode
}
#endregion Main Execution
