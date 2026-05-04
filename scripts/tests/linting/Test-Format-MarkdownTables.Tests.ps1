#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RealScript = (Resolve-Path (Join-Path $PSScriptRoot '../../linting/Format-MarkdownTables.ps1')).Path
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:RealNodeModules = Join-Path $script:RepoRoot 'node_modules'

    if (-not (Test-Path $script:RealNodeModules)) {
        throw "Cannot run Format-MarkdownTables tests: node_modules missing at $script:RealNodeModules. Run 'npm install' first."
    }

    $tempBase = [System.IO.Path]::GetTempPath()
    $script:MainTestRoot = Join-Path $tempBase "pester-fmt-tables-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:MainTestRoot -Force | Out-Null

    # Junction node_modules at MainTestRoot (one level above each fixture) so the
    # ESM resolver walks UP from fixture cwd and finds it. Placing it INSIDE a
    # fixture would cause that fixture's `git ls-files` to enumerate junctioned
    # content. NODE_PATH is CommonJS-only and does not work for ESM imports.
    $script:MainNodeModulesLink = Join-Path $script:MainTestRoot 'node_modules'
    if (-not (Test-Path $script:MainNodeModulesLink)) {
        if ($IsWindows) {
            & cmd /c "mklink /J `"$script:MainNodeModulesLink`" `"$script:RealNodeModules`"" 2>&1 | Out-Null
        }
        else {
            New-Item -ItemType SymbolicLink -Path $script:MainNodeModulesLink -Target $script:RealNodeModules | Out-Null
        }
    }

    function script:New-FixtureRepo {
        param(
            [Parameter(Mandatory)] [string] $Name,
            [switch] $InitGit
        )

        $fixtureRoot = Join-Path $script:MainTestRoot $Name
        $linting = Join-Path $fixtureRoot 'scripts/linting'
        New-Item -ItemType Directory -Path $linting -Force | Out-Null
        Copy-Item -Path $script:RealScript -Destination (Join-Path $linting 'Format-MarkdownTables.ps1') -Force

        if ($InitGit) {
            Push-Location $fixtureRoot
            try {
                & git init --quiet 2>&1 | Out-Null
                & git config user.email 'test@example.com' 2>&1 | Out-Null
                & git config user.name 'Test' 2>&1 | Out-Null
                & git config core.autocrlf false 2>&1 | Out-Null
                & git config core.safecrlf false 2>&1 | Out-Null
            }
            finally {
                Pop-Location
            }
        }

        # .gitignore (in addition to in-repo init) so git ls-files --others
        # --exclude-standard skips the junctioned node_modules tree and the
        # captured stdout/stderr files.
        $gitignore = @'
node_modules/
_stdout.txt
_stderr.txt
'@
        Set-Content -Path (Join-Path $fixtureRoot '.gitignore') -Value $gitignore -Encoding utf8

        return $fixtureRoot
    }

    function script:Invoke-SutInFixture {
        param(
            [Parameter(Mandatory)] [string] $FixtureRoot,
            [switch] $Check,
            [switch] $WithVerbose
        )

        $sutPath = Join-Path $FixtureRoot 'scripts/linting/Format-MarkdownTables.ps1'
        $stdoutPath = Join-Path $FixtureRoot '_stdout.txt'
        $stderrPath = Join-Path $FixtureRoot '_stderr.txt'

        $argList = @('-NoProfile', '-File', $sutPath)
        if ($Check) { $argList += '-Check' }
        if ($WithVerbose) { $argList += '-Verbose' }

        $proc = Start-Process -FilePath 'pwsh' `
            -ArgumentList $argList `
            -WorkingDirectory $FixtureRoot `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -Wait -PassThru -NoNewWindow

        # Belt-and-suspenders: ensure the process has fully exited and OS file
        # buffers have flushed before we read. Tiny stdout payloads under the
        # Pester runspace can race the file-handle close.
        $proc.WaitForExit()
        $stdoutBytes = if (Test-Path $stdoutPath) { (Get-Item $stdoutPath).Length } else { -1 }
        $stderrBytes = if (Test-Path $stderrPath) { (Get-Item $stderrPath).Length } else { -1 }
        if ($stdoutBytes -eq 0 -and $proc.ExitCode -eq 0) {
            Start-Sleep -Milliseconds 100
            $stdoutBytes = (Get-Item $stdoutPath).Length
        }

        $stdout = if ($stdoutBytes -gt 0) { [System.IO.File]::ReadAllText($stdoutPath) } else { '' }
        $stderr = if ($stderrBytes -gt 0) { [System.IO.File]::ReadAllText($stderrPath) } else { '' }

        return [pscustomobject]@{
            ExitCode    = $proc.ExitCode
            StdOut      = $stdout
            StdErr      = $stderr
            StdOutPath  = $stdoutPath
            StdErrPath  = $stderrPath
            StdOutBytes = $stdoutBytes
            StdErrBytes = $stderrBytes
        }
    }

    # Well-formatted table (each cell padded to column width, single space between pipes).
    $script:GoodTable = @'
# Good

| Name | Value |
|------|-------|
| a    | 1     |
| b    | 2     |
'@

    # Misformatted: cells flush against pipes, uneven widths.
    $script:BadTable = @'
# Bad

|Name|Value|
|---|---|
|a|1|
|bbb|22|
'@
}

AfterAll {
    if ($script:MainTestRoot -and (Test-Path $script:MainTestRoot)) {
        # CRITICAL: the MainTestRoot/node_modules junction points at the real
        # repo's node_modules. Remove it first via the directory-delete API
        # (which deletes the link itself, not the target) so the subsequent
        # recursive remove cannot follow it into real content.
        if ($script:MainNodeModulesLink -and (Test-Path $script:MainNodeModulesLink)) {
            try { [System.IO.Directory]::Delete($script:MainNodeModulesLink, $false) } catch { Write-Verbose "junction cleanup ignored: $_" }
        }
        Remove-Item -Path $script:MainTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Format-MarkdownTables' -Tag 'Unit' {

    Context 'when no markdown files are tracked' {
        BeforeAll {
            $script:Fixture = New-FixtureRepo -Name "empty-$(Get-Random)" -InitGit
            $script:Result = Invoke-SutInFixture -FixtureRoot $script:Fixture
        }

        It 'Exits 0' {
            $script:Result.ExitCode | Should -Be 0
        }

        It 'Reports no markdown files found' {
            $script:Result.StdOut | Should -Match 'No markdown files found' -Because (
                "ExitCode=$($script:Result.ExitCode); StdOutBytes=$($script:Result.StdOutBytes); " +
                "StdErrBytes=$($script:Result.StdErrBytes); StdErr=[$($script:Result.StdErr)]"
            )
        }
    }

    Context 'when invoked outside a git checkout' {
        BeforeAll {
            $script:Fixture = New-FixtureRepo -Name "no-git-$(Get-Random)"
            $script:Result = Invoke-SutInFixture -FixtureRoot $script:Fixture
        }

        It 'Exits with a non-zero code' {
            $script:Result.ExitCode | Should -Not -Be 0
        }

        It 'Reports the git ls-files failure on stderr' {
            $script:Result.StdErr | Should -Match 'git ls-files failed'
        }
    }

    Context 'when all markdown tables are already formatted' {
        BeforeAll {
            $script:Fixture = New-FixtureRepo -Name "good-$(Get-Random)" -InitGit
            Set-Content -Path (Join-Path $script:Fixture 'README.md') -Value $script:GoodTable -NoNewline
            $script:Result = Invoke-SutInFixture -FixtureRoot $script:Fixture
        }

        It 'Exits 0' {
            $script:Result.ExitCode | Should -Be 0
        }

        It 'Exits 0 in -Check mode' {
            $checkResult = Invoke-SutInFixture -FixtureRoot $script:Fixture -Check
            $checkResult.ExitCode | Should -Be 0
        }
    }

    Context 'when markdown tables need reformatting' {
        BeforeEach {
            $script:Fixture = New-FixtureRepo -Name "bad-$(Get-Random)" -InitGit
            $script:BadFile = Join-Path $script:Fixture 'README.md'
            Set-Content -Path $script:BadFile -Value $script:BadTable -NoNewline
        }

        It 'Exits non-zero in -Check mode' {
            $result = Invoke-SutInFixture -FixtureRoot $script:Fixture -Check
            $result.ExitCode | Should -Not -Be 0
        }

        It 'Leaves files unchanged in -Check mode' {
            $before = Get-Content -Path $script:BadFile -Raw
            $null = Invoke-SutInFixture -FixtureRoot $script:Fixture -Check
            $after = Get-Content -Path $script:BadFile -Raw
            $after | Should -BeExactly $before
        }

        It 'Exits 0 and rewrites the file in default mode' {
            $before = Get-Content -Path $script:BadFile -Raw
            $result = Invoke-SutInFixture -FixtureRoot $script:Fixture
            $result.ExitCode | Should -Be 0
            $after = Get-Content -Path $script:BadFile -Raw
            $after | Should -Not -BeExactly $before
            $after | Should -Match '\|\s+Name\s+\|\s+Value\s+\|'
        }
    }

    Context 'when markdown files live under dot-prefixed directories' {
        BeforeEach {
            $script:Fixture = New-FixtureRepo -Name "dotpath-$(Get-Random)" -InitGit
            $dotDir = Join-Path $script:Fixture '.github'
            New-Item -ItemType Directory -Path $dotDir -Force | Out-Null
            $script:DotFile = Join-Path $dotDir 'NOTES.md'
            Set-Content -Path $script:DotFile -Value $script:BadTable -NoNewline
        }

        It 'Detects misformatted tables under .github (regression: glob v13 dot:false)' {
            $result = Invoke-SutInFixture -FixtureRoot $script:Fixture -Check
            $result.ExitCode | Should -Not -Be 0
        }

        It 'Reformats files under .github in default mode' {
            $before = Get-Content -Path $script:DotFile -Raw
            $result = Invoke-SutInFixture -FixtureRoot $script:Fixture
            $result.ExitCode | Should -Be 0
            $after = Get-Content -Path $script:DotFile -Raw
            $after | Should -Not -BeExactly $before
        }
    }

    Context 'when -Verbose is supplied' {
        BeforeAll {
            $script:Fixture = New-FixtureRepo -Name "verbose-$(Get-Random)" -InitGit
            Set-Content -Path (Join-Path $script:Fixture 'README.md') -Value $script:GoodTable -NoNewline
            $script:Result = Invoke-SutInFixture -FixtureRoot $script:Fixture -WithVerbose
        }

        It 'Exits 0' {
            $script:Result.ExitCode | Should -Be 0
        }

        It 'Emits the file count to the verbose stream' {
            # PowerShell verbose output is written to stderr when captured from a child process.
            $script:Result.StdErr | Should -Match 'Formatting \d+ markdown file'
        }
    }
}
