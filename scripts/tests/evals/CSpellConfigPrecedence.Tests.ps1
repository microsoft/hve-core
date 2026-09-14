#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:CSpellBin = Join-Path $script:RepoRoot 'node_modules/cspell/bin.mjs'
    $script:NodeAvailable = $null -ne (Get-Command node -ErrorAction SilentlyContinue)

    function New-FixtureFile {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][string]$Content
        )

        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
    }

    function New-FixtureConfig {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][hashtable]$Settings
        )

        New-FixtureFile -Path $Path -Content (ConvertTo-Json -InputObject $Settings -Depth 10)
    }

    function New-FixtureRoot {
        New-Item -ItemType Directory -Path (Join-Path $TestDrive ([Guid]::NewGuid().ToString('N'))) -Force |
            Select-Object -ExpandProperty FullName
    }

    # Runs the repository-pinned cspell CLI against a disposable fixture and parses its observables.
    function Invoke-FixtureCSpell {
        param(
            [Parameter(Mandatory)][string]$Root,
            [string[]]$CSpellArgs = @('**/*.md')
        )

        if (-not $script:NodeAvailable) {
            throw 'node was not found on PATH. The CSpell precedence oracle requires Node to invoke the pinned CLI.'
        }
        if (-not (Test-Path -LiteralPath $script:CSpellBin)) {
            throw "The repository-pinned cspell CLI was not found at '$script:CSpellBin'. Run 'npm ci' at the repository root first."
        }

        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = 'node'
        $startInfo.WorkingDirectory = $Root
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        @($script:CSpellBin, 'lint') + $CSpellArgs + @('--no-progress', '--no-color') |
            ForEach-Object { $null = $startInfo.ArgumentList.Add($_) }

        $process = [System.Diagnostics.Process]::Start($startInfo)
        if ($null -eq $process) {
            throw 'Failed to start the repository-pinned cspell CLI through Node.'
        }

        $standardOutput = $process.StandardOutput.ReadToEndAsync()
        $standardError = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $raw = @($standardOutput.Result, $standardError.Result) -join [Environment]::NewLine
        $process.Dispose()

        $lines = @($raw -split '\r?\n' | Where-Object { $_ })

        $issues = @(
            foreach ($line in $lines) {
                if ($line -match '^(?<path>.+?):(?<line>\d+):(?<col>\d+)\s+-\s+Unknown word \((?<word>[^)]+)\)') {
                    [pscustomobject]@{ Path = $Matches.path; Word = $Matches.word }
                }
            }
        )

        $filesChecked = -1
        $issuesFound = -1
        foreach ($line in $lines) {
            if ($line -match 'Files checked:\s*(?<checked>\d+),\s*Issues found:\s*(?<issues>\d+)') {
                $filesChecked = [int]$Matches.checked
                $issuesFound = [int]$Matches.issues
            }
        }

        [pscustomobject]@{
            Issues       = $issues
            UnknownWords = @($issues | ForEach-Object { $_.Word })
            FilesChecked = $filesChecked
            IssuesFound  = $issuesFound
            Output       = $lines
        }
    }

    # Unknown words reported for one fixture-relative file, using the forward-slash paths cspell emits.
    function Get-FixtureUnknownWord {
        param(
            [Parameter(Mandatory)][psobject]$Result,
            [Parameter(Mandatory)][string]$RelativePath
        )

        @($Result.Issues | Where-Object { $_.Path.Replace('\\', '/') -eq $RelativePath } | ForEach-Object { $_.Word })
    }
}

Describe 'CSpell configuration precedence oracle' -Tag 'Unit' {

    Context 'Test prerequisites' {
        It 'Resolves Node and the repository-pinned cspell CLI' {
            $script:NodeAvailable | Should -BeTrue -Because 'the oracle invokes the pinned cspell CLI through Node'
            Test-Path -LiteralPath $script:CSpellBin | Should -BeTrue -Because "npm ci must install cspell at '$script:CSpellBin'"
        }
    }

    Context 'Scenario 1: root-only configuration' {
        It 'Loads root inline words and an enabled root dictionary' {
            $root = New-FixtureRoot
            New-FixtureFile -Path (Join-Path $root 'dicts/base.txt') -Content 'zzdictword'
            New-FixtureConfig -Path (Join-Path $root '.cspell.json') -Settings @{
                version               = '0.2'
                language              = 'en'
                words                 = @('zzrootword')
                ignorePaths           = @()
                dictionaryDefinitions = @(@{ name = 'zzbasedict'; path = './dicts/base.txt' })
                dictionaries          = @('zzbasedict')
            }
            New-FixtureFile -Path (Join-Path $root 'doc.md') -Content 'zzrootword zzdictword zzcontrolword'

            $result = Invoke-FixtureCSpell -Root $root

            $result.FilesChecked | Should -Be 1
            $result.UnknownWords | Should -Contain 'zzcontrolword'
            $result.UnknownWords | Should -Not -Contain 'zzrootword'
            $result.UnknownWords | Should -Not -Contain 'zzdictword'
        }
    }

    Context 'Scenario 2: root plus nested standalone configuration' {
        It 'Accumulates word arrays, lets the nested scalar win, and keeps discovery with the root' {
            $root = New-FixtureRoot
            New-FixtureConfig -Path (Join-Path $root '.cspell.json') -Settings @{
                version            = '0.2'
                language           = 'en'
                words              = @('zzrootword', 'zzalpha', 'zzbeta')
                allowCompoundWords = $true
                ignorePaths        = @('**/skipped/**')
            }
            New-FixtureConfig -Path (Join-Path $root 'pkg/.cspell.json') -Settings @{
                version            = '0.2'
                words              = @('zznestedword')
                allowCompoundWords = $false
            }
            New-FixtureFile -Path (Join-Path $root 'top.md') -Content 'zzrootword zzalphazzbeta'
            New-FixtureFile -Path (Join-Path $root 'pkg/doc.md') -Content 'zzrootword zznestedword zzalphazzbeta'
            New-FixtureFile -Path (Join-Path $root 'pkg/skipped/ignored.md') -Content 'zzignoredword'

            $result = Invoke-FixtureCSpell -Root $root

            $result.FilesChecked | Should -Be 2 -Because 'the invocation-base ignorePaths governs discovery for nested directories'
            $result.UnknownWords | Should -Not -Contain 'zzignoredword'
            $result.UnknownWords | Should -Not -Contain 'zzrootword' -Because 'root settings still apply beneath a nested config'
            $result.UnknownWords | Should -Not -Contain 'zznestedword' -Because 'the nested word array accumulates onto the root array'
            (Get-FixtureUnknownWord -Result $result -RelativePath 'pkg/doc.md') | Should -Contain 'zzalphazzbeta' -Because 'the nested scalar overrides the root scalar'
            (Get-FixtureUnknownWord -Result $result -RelativePath 'top.md') | Should -Not -Contain 'zzalphazzbeta' -Because 'the same compound still passes above the nested config'
        }
    }

    Context 'Scenario 3: embedded versus sibling configuration in one directory' {
        It 'Selects package.json#cspell over a sibling .cspell.json without merging the sibling' {
            $root = New-FixtureRoot
            New-FixtureConfig -Path (Join-Path $root '.cspell.json') -Settings @{
                version     = '0.2'
                language    = 'en'
                words       = @('zzrootword')
                ignorePaths = @()
            }
            New-FixtureConfig -Path (Join-Path $root 'pkg/package.json') -Settings @{
                name    = 'zz-fixture-pkg'
                version = '1.0.0'
                cspell  = @{ words = @('zzembedded') }
            }
            New-FixtureConfig -Path (Join-Path $root 'pkg/.cspell.json') -Settings @{
                version = '0.2'
                words   = @('zzsibling')
            }
            New-FixtureFile -Path (Join-Path $root 'pkg/doc.md') -Content 'zzrootword zzembedded zzsibling'

            $result = Invoke-FixtureCSpell -Root $root

            $result.UnknownWords | Should -Not -Contain 'zzembedded' -Because 'package.json#cspell precedes .cspell.json in the same directory'
            $result.UnknownWords | Should -Contain 'zzsibling' -Because 'an unselected sibling participates only through an explicit import'
            $result.UnknownWords | Should -Not -Contain 'zzrootword'
        }
    }

    Context 'Scenario 4: nearest configuration skips an intermediate ancestor' {
        It 'Applies the base and the nearest config but not an unimported intermediate ancestor' {
            $root = New-FixtureRoot
            New-FixtureConfig -Path (Join-Path $root '.cspell.json') -Settings @{
                version     = '0.2'
                language    = 'en'
                words       = @('zzrootword')
                ignorePaths = @()
            }
            New-FixtureConfig -Path (Join-Path $root 'a/.cspell.json') -Settings @{
                version = '0.2'
                words   = @('zzparentword')
            }
            New-FixtureConfig -Path (Join-Path $root 'a/b/.cspell.json') -Settings @{
                version = '0.2'
                words   = @('zzchildword')
            }
            New-FixtureFile -Path (Join-Path $root 'a/b/doc.md') -Content 'zzrootword zzparentword zzchildword'

            $result = Invoke-FixtureCSpell -Root $root

            $result.UnknownWords | Should -Not -Contain 'zzrootword' -Because 'the invocation base always participates'
            $result.UnknownWords | Should -Not -Contain 'zzchildword' -Because 'the nearest config overlays the base'
            $result.UnknownWords | Should -Contain 'zzparentword' -Because 'only the nearest ancestor config is applied'
        }
    }

    Context 'Scenario 5: explicit config and config-search controls' {
        BeforeEach {
            $script:SearchRoot = New-FixtureRoot
            New-FixtureConfig -Path (Join-Path $script:SearchRoot 'base.cspell.json') -Settings @{
                version     = '0.2'
                language    = 'en'
                words       = @('zzbaseword')
                ignorePaths = @()
            }
            New-FixtureConfig -Path (Join-Path $script:SearchRoot 'base-nosearch.cspell.json') -Settings @{
                version        = '0.2'
                language       = 'en'
                words          = @('zzbaseword')
                ignorePaths    = @()
                noConfigSearch = $true
            }
            New-FixtureConfig -Path (Join-Path $script:SearchRoot 'pkg/.cspell.json') -Settings @{
                version = '0.2'
                words   = @('zznestedword')
            }
            New-FixtureFile -Path (Join-Path $script:SearchRoot 'pkg/doc.md') -Content 'zzbaseword zznestedword zzcontrolword'
        }

        It 'Keeps per-file search enabled when only --config is supplied' {
            $result = Invoke-FixtureCSpell -Root $script:SearchRoot -CSpellArgs @('**/*.md', '--config', 'base.cspell.json')

            $result.UnknownWords | Should -Not -Contain 'zzbaseword'
            $result.UnknownWords | Should -Not -Contain 'zznestedword' -Because '--config alone does not disable the nearest-config search'
            $result.UnknownWords | Should -Contain 'zzcontrolword'
        }

        It 'Suppresses the nested config when --no-config-search is supplied' {
            $result = Invoke-FixtureCSpell -Root $script:SearchRoot -CSpellArgs @('**/*.md', '--config', 'base.cspell.json', '--no-config-search')

            $result.UnknownWords | Should -Not -Contain 'zzbaseword' -Because 'the explicit base stays active'
            $result.UnknownWords | Should -Contain 'zznestedword'
            $result.UnknownWords | Should -Contain 'zzcontrolword'
        }

        It 'Suppresses the nested config when the base sets noConfigSearch' {
            $result = Invoke-FixtureCSpell -Root $script:SearchRoot -CSpellArgs @('**/*.md', '--config', 'base-nosearch.cspell.json')

            $result.UnknownWords | Should -Not -Contain 'zzbaseword'
            $result.UnknownWords | Should -Contain 'zznestedword'
        }

        It 'Restores the nested config when --config-search overrides the base setting' {
            $result = Invoke-FixtureCSpell -Root $script:SearchRoot -CSpellArgs @('**/*.md', '--config', 'base-nosearch.cspell.json', '--config-search')

            $result.UnknownWords | Should -Not -Contain 'zzbaseword'
            $result.UnknownWords | Should -Not -Contain 'zznestedword' -Because 'the CLI flag overrides the base noConfigSearch setting'
            $result.UnknownWords | Should -Contain 'zzcontrolword'
        }
    }

    Context 'Scenario 6: import order' {
        It 'Accumulates imported and local arrays while the importing config supplies the winning scalar' {
            $root = New-FixtureRoot
            New-FixtureConfig -Path (Join-Path $root 'shared.cspell.json') -Settings @{
                version            = '0.2'
                words              = @('zzimportword', 'zzcompa', 'zzcompb')
                allowCompoundWords = $true
            }
            New-FixtureConfig -Path (Join-Path $root '.cspell.json') -Settings @{
                version            = '0.2'
                language           = 'en'
                import             = @('./shared.cspell.json')
                words              = @('zzlocalword')
                allowCompoundWords = $false
                ignorePaths        = @()
            }
            New-FixtureFile -Path (Join-Path $root 'doc.md') -Content 'zzimportword zzlocalword zzcompazzcompb'

            $result = Invoke-FixtureCSpell -Root $root

            $result.UnknownWords | Should -Not -Contain 'zzimportword' -Because 'imported word arrays accumulate'
            $result.UnknownWords | Should -Not -Contain 'zzlocalword'
            $result.UnknownWords | Should -Contain 'zzcompazzcompb' -Because 'the importing config scalar wins over the imported scalar'
        }
    }

    Context 'Scenario 7: dictionary collision, activation, and path relativity' {
        It 'Uses the later same-name definition, accumulates distinct names, and ignores unenabled definitions' {
            $root = New-FixtureRoot
            New-FixtureFile -Path (Join-Path $root 'dicts/root-shared.txt') -Content 'zzrootshared'
            New-FixtureFile -Path (Join-Path $root 'dicts/root-only.txt') -Content 'zzrootonlyword'
            New-FixtureFile -Path (Join-Path $root 'dicts/unused.txt') -Content 'zzunusedword'
            New-FixtureFile -Path (Join-Path $root 'pkg/dicts/pkg-shared.txt') -Content 'zzpkgshared'
            New-FixtureFile -Path (Join-Path $root 'pkg/dicts/pkg-only.txt') -Content 'zzpkgonlyword'

            New-FixtureConfig -Path (Join-Path $root '.cspell.json') -Settings @{
                version               = '0.2'
                language              = 'en'
                ignorePaths           = @()
                dictionaryDefinitions = @(
                    @{ name = 'zzshareddict'; path = './dicts/root-shared.txt' }
                    @{ name = 'zzrootonlydict'; path = './dicts/root-only.txt' }
                    @{ name = 'zzunuseddict'; path = './dicts/unused.txt' }
                )
                dictionaries          = @('zzshareddict', 'zzrootonlydict')
            }
            New-FixtureConfig -Path (Join-Path $root 'pkg/.cspell.json') -Settings @{
                version               = '0.2'
                dictionaryDefinitions = @(
                    @{ name = 'zzshareddict'; path = './dicts/pkg-shared.txt' }
                    @{ name = 'zzpkgonlydict'; path = './dicts/pkg-only.txt' }
                )
                dictionaries          = @('zzshareddict', 'zzpkgonlydict')
            }
            New-FixtureFile -Path (Join-Path $root 'pkg/doc.md') -Content 'zzrootshared zzpkgshared zzrootonlyword zzpkgonlyword zzunusedword'
            New-FixtureFile -Path (Join-Path $root 'top.md') -Content 'zzrootshared zzpkgshared'

            $result = Invoke-FixtureCSpell -Root $root

            $nested = Get-FixtureUnknownWord -Result $result -RelativePath 'pkg/doc.md'
            $top = Get-FixtureUnknownWord -Result $result -RelativePath 'top.md'

            $nested | Should -Contain 'zzunusedword' -Because 'a defined but unenabled dictionary never loads'
            $nested | Should -Not -Contain 'zzpkgshared' -Because 'the later same-name definition replaces the earlier one and its path resolves from the defining config'
            $nested | Should -Not -Contain 'zzrootonlyword' -Because 'distinct enabled dictionary names accumulate across the merge'
            $nested | Should -Not -Contain 'zzpkgonlyword'
            $nested | Should -Contain 'zzrootshared' -Because 'the replaced same-name definition no longer supplies its words beneath the nested config'

            $top | Should -Not -Contain 'zzrootshared' -Because 'the root definition still applies where no nested config overrides it'
            $top | Should -Contain 'zzpkgshared' -Because 'the nested dictionary does not apply above the config that defines it'
        }
    }
}
