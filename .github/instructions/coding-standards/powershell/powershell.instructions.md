---
description: "Instructions for PowerShell scripting implementation - Brought to you by microsoft/hve-core"
applyTo: '**/*.ps1, **/*.psm1, **/*.psd1'
---

# PowerShell Script Instructions

These instructions define conventions for authoring PowerShell scripts, modules, and data files in this repository. Apply these conventions to `.ps1` scripts, `.psm1` modules, and `.psd1` data files.

## Copyright Headers

Every PowerShell file requires a copyright header containing two lines:

```powershell
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
```

Placement varies by file type:

```powershell
# Script (.ps1): after shebang, before #Requires
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

# Module (.psm1): first lines (no shebang)
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Test file (.Tests.ps1): after #Requires -Modules Pester
#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Data file (.psd1): first lines (no shebang)
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
```

CI validates copyright headers via `npm run validate:copyright` using `scripts/linting/Test-CopyrightHeaders.ps1`.

## Script Structure

Production scripts follow a 10-section structure. Each section appears in the order documented below.

### Shebang

`#!/usr/bin/env pwsh` is required on all `.ps1` files for cross-platform portability. Do not include a shebang on `.psm1` or `.psd1` files.

### Requires Statements

`#Requires -Version 7.0` is required on all scripts and modules. Place it after the copyright header. In modules, place the `#Requires` statement after the copyright header and purpose comment.

### Comment-Based Help

Use block comment style with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, and `.NOTES` sections:

```powershell
<#
.SYNOPSIS
    Brief one-line description.
.DESCRIPTION
    Detailed description of what the script does.
.PARAMETER RepoRoot
    Root directory of the repository.
.EXAMPLE
    ./Invoke-ScriptName.ps1 -RepoRoot /repo
.NOTES
    Runs via: npm run script-name
#>
```

### CmdletBinding and Parameters

`[CmdletBinding()]` with a typed `param()` block is required on all scripts. Declare parameter types, defaults, and `Mandatory` attributes explicitly:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (git rev-parse --show-toplevel 2>$null) ?? $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $RepoRoot 'logs/results.json')
)
```

### Error Preference

Set `$ErrorActionPreference = 'Stop'` immediately after the param block. This ensures unhandled errors terminate execution.

### Module Imports

Import module dependencies using the `Join-Path` pattern with `-Force` to ensure fresh imports:

```powershell
Import-Module (Join-Path $PSScriptRoot 'Modules/Helpers.psm1') -Force
```

### Region Blocks

Use `#region`/`#endregion` with descriptive labels to group logical sections:

```powershell
#region Functions
# ... function definitions
#endregion Functions

#region Main Execution
# ... entry point logic
#endregion Main Execution
```

### Main Execution Guard

Wrap main execution in an invocation guard that enables dot-sourcing for test files. This pattern ensures main execution only runs when the script is invoked directly, not when dot-sourced by Pester tests:

```powershell
if ($MyInvocation.InvocationName -ne '.') {
    # Main execution logic
}
```

## Module Structure

Module files (`.psm1`) follow a distinct pattern from scripts:

* No shebang line
* Purpose comment after the copyright header: `# ModuleName.psm1` and `# Purpose: ...`
* `#Requires -Version 7.0` after the purpose comment
* Functions with full comment-based help, `[CmdletBinding()]`, and `[OutputType()]`
* Explicit `Export-ModuleMember -Function @(...)` at the end of the file

For class-only modules that expose no standalone functions, use `Export-ModuleMember -Function @()`. Consumers import class-only modules with `using module` for type availability.

```powershell
# Classes.psm1
class ValidationResult {
    [string]$Name
    [bool]$Passed
}

Export-ModuleMember -Function @()
```

Consumer usage:

```powershell
using module './Classes.psm1'
```

## Naming Conventions

| Element    | Convention           | Example                       |
|------------|----------------------|-------------------------------|
| Functions  | Verb-Noun PascalCase | `Get-ValidationResult`        |
| Scripts    | Verb-Noun PascalCase | `Invoke-PSScriptAnalyzer.ps1` |
| Parameters | PascalCase with type | `[string]$OutputPath`         |
| Variables  | PascalCase           | `$ResultList`                 |
| Modules    | PascalCase           | `CIHelpers.psm1`              |

## Error Handling

Set `$ErrorActionPreference = 'Stop'` at the script level. Use try-catch blocks in the main execution guard with explicit exit codes.

Error action preferences for different contexts:

* `Write-Error -ErrorAction Continue` for non-fatal errors in catch blocks
* `-ErrorAction SilentlyContinue` for optional command checks (e.g., testing if a command exists)
* `-ErrorAction Stop` for critical operations that must succeed
* `$LASTEXITCODE` checks after external commands (e.g., `git`, `npm`)
* `throw` for validation failures within functions

```powershell
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-CoreFunction -RepoRoot $RepoRoot
        $result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "ScriptName failed: $($_.Exception.Message)"
        exit 1
    }
}
```

## Output and Logging

### Console Output

`Write-Host` with `-ForegroundColor` and emoji prefixes provides visual feedback during local development. `Write-Host` is allowed in this codebase (PSAvoidUsingWriteHost is excluded from PSScriptAnalyzer rules).

```powershell
Write-Host "✅ Validation passed: $count files clean" -ForegroundColor Green
Write-Host "⚠️  Warning: $skipped files skipped" -ForegroundColor Yellow
Write-Host "❌ Validation failed: $errors errors found" -ForegroundColor Red
```

### CI Integration

The CI output API from `scripts/lib/Modules/CIHelpers.psm1` provides platform-abstracted functions:

* `Write-CIAnnotation` for CI annotations (GitHub Actions `::warning::`, Azure DevOps `##vso[task.logissue]`, local `Write-Warning`)
* `Set-CIOutput` for step output variables
* `Write-CIStepSummary` for markdown step summaries
* `Set-CIEnv` for persistent CI environment variables

```powershell
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Write-CIAnnotation -Level 'Warning' -Message 'Deprecated API usage detected' -File $filePath -Line $lineNum
```

### JSON Results

Write structured output to the `logs/` directory for downstream consumption. Use `ConvertTo-Json` with sufficient depth and UTF8 encoding:

```powershell
$result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
```

## Parameter Validation

Apply validation attributes to enforce parameter constraints:

* `[ValidateNotNullOrEmpty()]` for required string parameters that must contain a value
* `[ValidateScript()]` for custom validation logic with scriptblock predicates
* `[ValidateSet()]` for parameters constrained to a fixed set of values

```powershell
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Error', 'Warning', 'Information')]
    [string]$Severity = 'Error'
)
```

## PSScriptAnalyzer Compliance

PSScriptAnalyzer configuration lives at `scripts/linting/PSScriptAnalyzer.psd1`. Run analysis via `npm run lint:ps`.

Key enforced rules:

* Approved verbs for function names (`PSUseApprovedVerbs`)
* Block comment-based help before function body (`PSProvideCommentHelp`)
* `[OutputType()]` attribute on functions (`PSUseOutputTypeCorrectly`)
* Full cmdlet names, no aliases (`PSAvoidUsingCmdletAliases`)
* Compatible syntax targeting PowerShell 5.1, 7.0, and 7.2 (`PSUseCompatibleSyntax`)

Allowed exceptions:

* `Write-Host` is permitted (PSAvoidUsingWriteHost excluded)
* Positional parameters are allowed (PSAvoidUsingPositionalParameters disabled)
* Singular nouns are allowed (PSUseSingularNouns disabled)

## Complete Script Example

<!-- <template-complete-script> -->
```powershell
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Brief one-line description.
.DESCRIPTION
    Detailed description of what the script does.
.PARAMETER RepoRoot
    Root directory of the repository.
.PARAMETER OutputPath
    Path for the JSON results file.
.EXAMPLE
    ./Invoke-ScriptName.ps1 -RepoRoot /repo -OutputPath logs/results.json
.NOTES
    Runs via: npm run script-name
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (git rev-parse --show-toplevel 2>$null) ?? $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $RepoRoot 'logs/results.json')
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/Helpers.psm1') -Force

#region Functions

function Invoke-CoreFunction {
    <#
    .SYNOPSIS
        Core logic for the script.
    .OUTPUTS
        [hashtable] Results object.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    # Implementation
    return @{ Status = 'Pass'; Issues = @() }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-CoreFunction -RepoRoot $RepoRoot
        $result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        exit 0
    }
    catch {
        Write-CIAnnotation -Level 'Error' -Message $_.Exception.Message
        Write-Error -ErrorAction Continue "ScriptName failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
```
<!-- </template-complete-script> -->

## Complete Module Example

<!-- <template-complete-module> -->
```powershell
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# HelperModule.psm1
# Purpose: Shared utility functions for area operations.

#Requires -Version 7.0

function Get-SomeData {
    <#
    .SYNOPSIS
        Retrieves structured data from source.
    .PARAMETER Path
        File path to read.
    .OUTPUTS
        [hashtable] Parsed data object.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    # Implementation
}

Export-ModuleMember -Function @(
    'Get-SomeData'
)
```
<!-- </template-complete-module> -->
