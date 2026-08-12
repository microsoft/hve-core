#Requires -Modules Pester

# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
    Locks the security properties of the shared test workflows.

    These two reusable workflows install dependencies from a caller-supplied
    directory while holding id-token: write for Codecov OIDC. That combination
    makes two properties load-bearing rather than stylistic:

      * Installs must not execute dependency lifecycle scripts, or any
        transitive package can run code in a job that can mint an identity
        token.
      * Caller input must not be interpolated into a run body, where its
        contents can terminate a shell word and inject commands.

    actionlint and yaml-lint validate syntax, not either property, so a future
    edit could reintroduce them while CI stays green. These tests assert the
    properties directly.
#>

# Discovery-time state. Pester evaluates -ForEach while discovering tests, which
# happens before BeforeAll runs, so anything a -ForEach reads must be defined at
# script scope here rather than inside BeforeAll. Defining it there generates
# zero test cases and the file passes without asserting anything.
$RepoRoot = (& git rev-parse --show-toplevel 2>$null)
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

$SharedTestWorkflows = @(
    (Join-Path $RepoRoot '.github/workflows/node-tests.yml'),
    (Join-Path $RepoRoot '.github/workflows/pytest-tests.yml')
)

# Returns each line that sits inside a `run: |` block body. YAML block scalars
# end when indentation returns to the step-key level, so the body is everything
# more indented than the `run:` key itself.
function Get-RunBodyLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = Get-Content -Path $Path
    $bodyIndent = -1
    $collected = @()

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]

        if ($bodyIndent -ge 0) {
            if ($line.Trim().Length -eq 0) {
                continue
            }
            $indent = $line.Length - $line.TrimStart().Length
            if ($indent -le $bodyIndent) {
                $bodyIndent = -1
            }
            else {
                $collected += [pscustomobject]@{
                    LineNumber = $index + 1
                    Text       = $line
                }
                continue
            }
        }

        if ($line -match '^\s*run:\s*\|') {
            $bodyIndent = $line.Length - $line.TrimStart().Length
        }
    }

    return $collected
}

Describe 'Shared test workflow injection surface' -Tag 'Unit', 'Security' {
    BeforeAll {
        # Pester runs discovery and execution in separate scopes, so the helper
        # and paths above are re-established here for the test bodies to use.
        $script:InstallScriptPath = Join-Path $RepoRoot 'scripts/ci/install-skill-node-deps.sh'

        function Get-RunBodyLine {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Path
            )

            $lines = Get-Content -Path $Path
            $bodyIndent = -1
            $collected = @()

            for ($index = 0; $index -lt $lines.Count; $index++) {
                $line = $lines[$index]

                if ($bodyIndent -ge 0) {
                    if ($line.Trim().Length -eq 0) {
                        continue
                    }
                    $indent = $line.Length - $line.TrimStart().Length
                    if ($indent -le $bodyIndent) {
                        $bodyIndent = -1
                    }
                    else {
                        $collected += [pscustomobject]@{
                            LineNumber = $index + 1
                            Text       = $line
                        }
                        continue
                    }
                }

                if ($line -match '^\s*run:\s*\|') {
                    $bodyIndent = $line.Length - $line.TrimStart().Length
                }
            }

            return $collected
        }
    }
    It 'Keeps template interpolation out of run bodies in <_>' -ForEach $SharedTestWorkflows {
        $workflow = $_
        Test-Path $workflow | Should -BeTrue -Because 'the workflow under test must exist'

        $offending = Get-RunBodyLine -Path $workflow | Where-Object { $_.Text -match '\$\{\{' }

        $detail = ($offending | ForEach-Object { "line $($_.LineNumber): $($_.Text.Trim())" }) -join "`n"
        $offending.Count | Should -Be 0 -Because "caller input must reach the shell through env:, not interpolation:`n$detail"
    }

    It 'Passes caller input through the environment in <_>' -ForEach $SharedTestWorkflows {
        $workflow = $_
        $content = Get-Content -Path $workflow -Raw

        $content | Should -Match 'env:' -Because 'inputs are provided to steps as environment variables'
    }
}

Describe 'Shared test workflow install hardening' -Tag 'Unit', 'Security' {
    BeforeAll {
        function Get-RunBodyLine {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Path
            )

            $lines = Get-Content -Path $Path
            $bodyIndent = -1
            $collected = @()

            for ($index = 0; $index -lt $lines.Count; $index++) {
                $line = $lines[$index]

                if ($bodyIndent -ge 0) {
                    if ($line.Trim().Length -eq 0) {
                        continue
                    }
                    $indent = $line.Length - $line.TrimStart().Length
                    if ($indent -le $bodyIndent) {
                        $bodyIndent = -1
                    }
                    else {
                        $collected += [pscustomobject]@{
                            LineNumber = $index + 1
                            Text       = $line
                        }
                        continue
                    }
                }

                if ($line -match '^\s*run:\s*\|') {
                    $bodyIndent = $line.Length - $line.TrimStart().Length
                }
            }

            return $collected
        }
    }
    It 'Routes dependency installation through the shared hardened script in <_>' -ForEach $SharedTestWorkflows {
        $workflow = $_
        $content = Get-Content -Path $workflow -Raw

        $content | Should -Match 'scripts/ci/install-skill-node-deps\.sh' -Because 'the install block has one owner'
    }

    It 'Does not run a bare npm ci in <_>' -ForEach $SharedTestWorkflows {
        $workflow = $_

        $bare = Get-RunBodyLine -Path $workflow |
            Where-Object { $_.Text -match 'npm ci' -and $_.Text -notmatch '--ignore-scripts' }

        $detail = ($bare | ForEach-Object { "line $($_.LineNumber): $($_.Text.Trim())" }) -join "`n"
        $bare.Count | Should -Be 0 -Because "a lifecycle script would execute in a job holding id-token: write:`n$detail"
    }
}

Describe 'Skill dependency install script' -Tag 'Unit', 'Security' {
    BeforeAll {
        $script:InstallScriptPath = Join-Path $RepoRoot 'scripts/ci/install-skill-node-deps.sh'
        $script:InstallScriptContent = Get-Content -Path $script:InstallScriptPath -Raw
    }

    It 'Exists at the path the workflows reference' {
        Test-Path $script:InstallScriptPath | Should -BeTrue
    }

    It 'Runs under strict mode' {
        $script:InstallScriptContent | Should -Match 'set -euo pipefail'
    }

    It 'Skips dependency lifecycle scripts' {
        $script:InstallScriptContent | Should -Match '--ignore-scripts'
    }

    It 'Bounds the number of installs' {
        $script:InstallScriptContent | Should -Match 'MAX_INSTALLS'
    }

    It 'Requires the search root rather than defaulting to a directory walk' {
        # ${VAR:?message} fails when the variable is unset, so an accidental
        # invocation cannot silently scan the repository root.
        $script:InstallScriptContent | Should -Match 'SEARCH_ROOT:\?'
    }

    It 'Omits optional dependencies by default' {
        # The screen-reader driver is a Windows-only optional dependency whose
        # chain writes to the registry; Linux CI never drives a screen reader.
        $script:InstallScriptContent | Should -Match '--omit=optional'
    }
}
