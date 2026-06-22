#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Regression test enforcing the dot-source guard convention.

.DESCRIPTION
    Every production script that a Pester test dot-sources must wrap its main
    logic in the guard `if ($MyInvocation.InvocationName -ne '.')`. Without it,
    dot-sourcing the script in a `BeforeAll` block executes the script's main
    logic (and any top-level `exit`) during test setup, which hangs or corrupts
    the run. This test discovers every dot-sourced target across the test suite
    and asserts the guard is present.
#>

BeforeDiscovery {
    $testsRoot = Join-Path $PSScriptRoot '..'

    function Get-StringLiteralPath {
        param([System.Management.Automation.Language.Ast]$Node)

        $literals = $Node.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
            }, $true)

        ($literals | Where-Object { $_.Value -match '\.ps1' } | Select-Object -First 1).Value
    }

    $discovered = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new()

    $testFiles = Get-ChildItem -Path $testsRoot -Recurse -Filter '*.Tests.ps1'

    foreach ($testFile in $testFiles) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $testFile.FullName, [ref]$tokens, [ref]$errors)

        $dotSources = $ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.CommandAst] -and
                $n.InvocationOperator -eq 'Dot'
            }, $true)

        foreach ($dotSource in $dotSources) {
            $literal = Get-StringLiteralPath -Node $dotSource

            if (-not $literal) {
                # Variable indirection: resolve `$path = Join-Path ...; . $path`.
                $variable = $dotSource.CommandElements[0] -as [System.Management.Automation.Language.VariableExpressionAst]
                if ($variable) {
                    $name = $variable.VariablePath.UserPath -replace '^script:', ''
                    $assignment = $ast.FindAll({
                            param($n)
                            $n -is [System.Management.Automation.Language.AssignmentStatementAst]
                        }, $true) | Where-Object {
                        $_.Left.Extent.Text -match ('\$(script:)?' + [regex]::Escape($name) + '\b')
                    } | Select-Object -First 1

                    if ($assignment) {
                        $literal = Get-StringLiteralPath -Node $assignment.Right
                    }
                }
            }

            if (-not $literal) { continue }

            $relative = $literal -replace '\$PSScriptRoot', '' -replace '^[\\/]+', ''
            $candidate = Join-Path $testFile.DirectoryName $relative
            $resolved = $null
            try {
                $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
            }
            catch {
                continue
            }

            if ($resolved -and $resolved -notmatch '\.Tests\.ps1$' -and $seen.Add($resolved)) {
                $discovered.Add(@{
                        TargetPath = $resolved
                        TargetName = Split-Path $resolved -Leaf
                        TestName   = $testFile.Name
                    })
            }
        }
    }

    $script:DotSourcedScripts = $discovered
}

Describe 'Dot-source guard convention' -Tag 'Unit' {
    It 'discovers at least one dot-sourced script' {
        $DotSourcedScripts.Count | Should -BeGreaterThan 0
    }

    It '<TargetName> guards main logic from dot-sourcing (referenced by <TestName>)' -ForEach $DotSourcedScripts {
        $content = Get-Content -LiteralPath $TargetPath -Raw
        $content | Should -Match "InvocationName\s+-ne\s+'\." -Because (
            "$TargetName is dot-sourced by $TestName and must wrap its main logic in " +
            "if (`$MyInvocation.InvocationName -ne '.') so test setup does not execute it"
        )
    }
}
