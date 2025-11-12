# PSScriptAnalyzer Settings for HVE Core
# Purpose: Enforce PowerShell best practices and coding standards

@{
    # Severity levels: Error, Warning, Information
    # Only include rules that should fail the build
    Severity = @('Error', 'Warning')

    # Include all default rules
    IncludeDefaultRules = $true

    # Exclude specific rules that may not apply
    ExcludeRules = @(
        # Allow Write-Host for user-facing scripts (console output is intentional)
        'PSAvoidUsingWriteHost',
        # Allow plural nouns for functions that semantically return multiple items (e.g., Get-GitIgnorePatterns)
        'PSUseSingularNouns',
        # Skip ShouldProcess for simple GitHub Actions helper functions that only append to files
        'PSUseShouldProcessForStateChangingFunctions',
        # Skip false positive for error redirection operator (2>$null)
        'PSPossibleIncorrectUsageOfRedirectionOperator'
    )

    # Custom rule configurations
    Rules = @{
        # Enforce cmdlet alias avoidance (use full cmdlet names)
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }

        # Require explicit parameter types
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('5.1', '7.0', '7.2')
        }

        # Enforce proper comment-based help
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $false
            BlockComment = $true
            VSCodeSnippetCorrection = $true
            Placement = 'before'
        }

        # Enforce proper OutputType declarations
        PSUseOutputTypeCorrectly = @{
            Enable = $true
        }

        # Enforce proper verb usage
        PSUseApprovedVerbs = @{
            Enable = $true
        }

        # Require BOM for UTF-8 encoded files
        PSUseBOMForUnicodeEncodedFile = @{
            Enable = $true
        }

        # Avoid using positional parameters
        PSAvoidUsingPositionalParameters = @{
            Enable = $false  # Disabled - common in scripts
        }
    }
}
