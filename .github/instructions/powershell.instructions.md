---
applyTo: '**/*.ps1'
description: 'Instructions for PowerShell scripting implementation - Brought to you by microsoft/hve-core'
maturity: stable
---

# PowerShell Script Instructions

Conventions for PowerShell 7.x scripts used in automation, tooling, and CI/CD pipelines. These instructions enforce PSScriptAnalyzer rules defined in `scripts/linting/PSScriptAnalyzer.psd1`.

## General Conventions

* Use approved verbs from `Get-Verb` for function names
* Prefer advanced functions with `[CmdletBinding()]` attribute
* Add `[OutputType()]` attribute to functions that return values
* Use full cmdlet names, never aliases (e.g., `Get-ChildItem` not `gci`)
* Target PowerShell versions: 5.1, 7.0, 7.2+
* Save files with UTF-8 BOM encoding

## Script Structure

```powershell
#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Brief description of the script.

.DESCRIPTION
    Detailed description of what the script does.

.PARAMETER ParameterName
    Description of the parameter.

.EXAMPLE
    ./Script-Name.ps1 -ParameterName "value"
    Description of what this example does.

.NOTES
    Additional notes about the script.

.LINK
    https://docs.example.com/reference
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ParameterName = "default"
)

# Script logic here
```

## Comment-Based Help

All scripts MUST include comment-based help with:

| Element | Required | Description |
|---------|----------|-------------|
| `.SYNOPSIS` | Yes | Brief one-line description |
| `.DESCRIPTION` | Yes | Detailed description |
| `.PARAMETER` | Yes | For each parameter |
| `.EXAMPLE` | Yes | At least one usage example |
| `.NOTES` | No | Additional notes, requirements |
| `.LINK` | No | Related documentation URLs |

Place help block immediately before `[CmdletBinding()]` using block comment syntax `<# #>`.

## PSScriptAnalyzer Compliance

The codebase enforces these rules via `scripts/linting/PSScriptAnalyzer.psd1`:

### Required

* `PSAvoidUsingCmdletAliases` - Use full cmdlet names
* `PSUseApprovedVerbs` - Use verbs from `Get-Verb`
* `PSProvideCommentHelp` - Include comment-based help
* `PSUseOutputTypeCorrectly` - Declare output types
* `PSUseBOMForUnicodeEncodedFile` - UTF-8 with BOM
* `PSUseCompatibleSyntax` - Target versions 5.1, 7.0, 7.2

### Excluded (Allowed)

* `PSAvoidUsingWriteHost` - OK for user-facing console output
* `PSUseSingularNouns` - OK for functions returning collections
* `PSUseShouldProcessForStateChangingFunctions` - OK for simple helpers

## Function Patterns

### Advanced Function Template

```powershell
function Verb-Noun {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InputPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        # One-time initialization
    }

    process {
        # Per-item processing for pipeline input
    }

    end {
        # Cleanup
    }
}
```

### Parameter Validation

```powershell
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[string]$RequiredString

[Parameter(Mandatory = $false)]
[ValidateSet('Option1', 'Option2', 'Option3')]
[string]$Choice = 'Option1'

[Parameter(Mandatory = $false)]
[ValidateRange(1, 100)]
[int]$Count = 10

[Parameter(Mandatory = $false)]
[ValidateScript({ Test-Path $_ })]
[string]$Path
```

## Error Handling

```powershell
# Set strict error handling at script level
$ErrorActionPreference = 'Stop'

# Try/catch for recoverable errors
try {
    $result = Get-Content -Path $filePath -ErrorAction Stop
}
catch [System.IO.FileNotFoundException] {
    Write-Warning "File not found: $filePath"
    return $null
}
catch {
    Write-Error "Unexpected error: $_"
    throw
}

# Terminating errors in advanced functions
$PSCmdlet.ThrowTerminatingError(
    [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new("Error message"),
        "ErrorId",
        [System.Management.Automation.ErrorCategory]::InvalidOperation,
        $targetObject
    )
)
```

## Output Conventions

* Use `Write-Host` for user-facing console output (colored status)
* Use `Write-Verbose` for detailed diagnostic info (`-Verbose`)
* Use `Write-Warning` for non-fatal warnings
* Use `Write-Error` for errors that don't stop execution
* Return structured objects, not formatted strings
* JSON output files go in `logs/` directory

```powershell
Write-Host "✅ Operation completed" -ForegroundColor Green
Write-Verbose "Processing file: $filePath"
Write-Warning "Configuration file not found, using defaults"

# Output structured data
$result = [PSCustomObject]@{
    timestamp = (Get-Date -Format "o")
    status = "success"
    count = $processedCount
}
$result | ConvertTo-Json | Set-Content -Path "logs/result.json"
```

## Pester Testing

Test files follow the pattern `<ScriptName>.Tests.ps1` in `scripts/tests/` mirroring source structure.

### Test File Structure

```powershell
#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Script-Name.ps1
.DESCRIPTION
    Tests covering:
    - Parameter validation
    - Core functionality
    - Error handling
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../path/to/Script-Name.ps1'
}

Describe 'Script-Name Functionality' -Tag 'Unit' {
    Context 'Parameter validation' {
        It 'Accepts valid parameters' {
            { & $script:ScriptPath -Param "value" } | Should -Not -Throw
        }

        It 'Rejects invalid parameters' {
            { & $script:ScriptPath -Param "" } | Should -Throw
        }
    }

    Context 'Core functionality' {
        BeforeEach {
            # Arrange - Setup for each test
            Mock Get-Content { "mocked content" }
        }

        It 'Returns expected output' {
            # Act
            $result = & $script:ScriptPath -Param "value"

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.status | Should -Be "success"
        }
    }
}
```

### Mocking External Dependencies

```powershell
# Mock cmdlets
Mock Get-Content { "mocked content" }
Mock Test-Path { $true }
Mock Invoke-RestMethod { @{ status = "ok" } }

# Mock with parameter filter
Mock Get-Module { $true } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }

# Mock module functions
Mock Get-ChangedFilesFromGit { @('file1.ps1', 'file2.ps1') }
```

## Module Patterns

For reusable code, create modules in `scripts/*/Modules/`:

```powershell
# ModuleName.psm1
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

function Get-PublicFunction {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    return "public"
}

function Get-PrivateHelper {
    # Not exported
    return "private"
}

Export-ModuleMember -Function Get-PublicFunction
```

## GitHub Actions Integration

For scripts running in GitHub Actions:

```powershell
# Set output variable
"name=value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append

# Set environment variable for subsequent steps
"VAR_NAME=value" | Out-File -FilePath $env:GITHUB_ENV -Append

# Write to step summary
"## Results`n`n✅ All checks passed" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append

# Create annotation
Write-Host "::warning file=script.ps1,line=10::Warning message"
Write-Host "::error file=script.ps1,line=20::Error message"
```

## References

* PSScriptAnalyzer rules: `scripts/linting/PSScriptAnalyzer.psd1`
* Existing scripts: `scripts/linting/`, `scripts/security/`, `scripts/lib/`
* Test examples: `scripts/tests/`
* Template guidance: `docs/templates/`
