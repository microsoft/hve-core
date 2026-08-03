#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../release/Update-VersionFiles.ps1'
    # Pass a dummy version to satisfy the mandatory parameter during dot-source.
    # The main execution guard prevents any file changes.
    . $script:ScriptPath -Version '0.0.0'
    Mock Write-Host {}
}

Describe 'Resolve-RepoRoot' -Tag 'Unit' {
    It 'Returns the supplied path when provided' {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "rr-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $result = Resolve-RepoRoot -Supplied $tempDir
            $result | Should -Be (Resolve-Path $tempDir).Path
        }
        finally {
            Remove-Item -Recurse -Force $tempDir
        }
    }

    It 'Auto-detects repo root when no path is supplied' {
        $result = Resolve-RepoRoot -Supplied ''
        $result | Should -Not -BeNullOrEmpty
        Test-Path (Join-Path $result '.git') | Should -BeTrue
    }

    It 'Throws when auto-detection fails and no path is supplied' {
        Mock Resolve-Path { return [PSCustomObject]@{ Path = '/nonexistent/path' } } -ParameterFilter {
            $Path -like "*..[\/]..*"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -like "*[\/].git"
        }
        { Resolve-RepoRoot -Supplied '' } | Should -Throw "*Unable to determine repository root*"
    }
}

Describe 'Update-JsonVersion' -Tag 'Unit' {
    BeforeAll {
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ujv-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item -Recurse -Force $script:TempDir
        }
    }

    It 'Updates a simple version field' {
        $filePath = Join-Path $script:TempDir 'simple.json'
        @{ version = '1.0.0'; name = 'test' } | ConvertTo-Json | Set-Content $filePath

        Update-JsonVersion -FilePath $filePath -Description 'simple.json' -Transform {
            param($j) $j.version = '2.0.0'; $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json
        $result.version | Should -Be '2.0.0'
        $result.name | Should -Be 'test'
        (Get-Content -Raw $filePath).EndsWith("`n", [System.StringComparison]::Ordinal) | Should -BeTrue
    }

    It 'Preserves a missing final newline' {
        $filePath = Join-Path $script:TempDir 'no-final-newline.json'
        [System.IO.File]::WriteAllText(
            $filePath,
            '{"version":"1.0.0"}',
            [System.Text.UTF8Encoding]::new($false)
        )

        Update-JsonVersion -FilePath $filePath -Description 'no-final-newline.json' -Transform {
            param($j) $j.version = '2.0.0'; $j
        }

        $content = Get-Content -Raw $filePath
        ($content | ConvertFrom-Json).version | Should -Be '2.0.0'
        $content.EndsWith("`n", [System.StringComparison]::Ordinal) | Should -BeFalse
    }

    It 'Skips without error when file does not exist' {
        $missingPath = Join-Path $script:TempDir 'does-not-exist.json'
        { Update-JsonVersion -FilePath $missingPath -Description 'missing' -Transform { param($j) $j } } |
            Should -Not -Throw
    }

    It 'Updates nested properties via transform' {
        $filePath = Join-Path $script:TempDir 'nested.json'
        @{
            metadata = @{ version = '1.0.0' }
            plugins  = @(@{ version = '1.0.0'; id = 'p1' })
        } | ConvertTo-Json -Depth 10 | Set-Content $filePath

        Update-JsonVersion -FilePath $filePath -Description 'nested.json' -Transform {
            param($j)
            $j.metadata.version = '3.0.0'
            foreach ($p in $j.plugins) { $p.version = '3.0.0' }
            $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json -Depth 10
        $result.metadata.version | Should -Be '3.0.0'
        $result.plugins[0].version | Should -Be '3.0.0'
    }

    It 'Preserves dot-key in release-please manifest' {
        $filePath = Join-Path $script:TempDir 'manifest.json'
        @{ '.' = '1.0.0' } | ConvertTo-Json | Set-Content $filePath

        Update-JsonVersion -FilePath $filePath -Description 'manifest' -Transform {
            param($j) $j.'.' = '4.0.0'; $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json
        $result.'.' | Should -Be '4.0.0'
    }

    It 'Updates both version and packages[""].version in package-lock.json' {
        $filePath = Join-Path $script:TempDir 'package-lock.json'
        @{
            name            = 'hve-core'
            version         = '1.0.0'
            lockfileVersion = 3
            packages        = @{ '' = @{ version = '1.0.0'; name = 'hve-core' } }
        } | ConvertTo-Json -Depth 10 | Set-Content $filePath

        $targetVersion = '5.0.0'
        Update-JsonVersion -FilePath $filePath -Description 'package-lock.json' -AsHashtable -Transform {
            param($j)
            $j['version'] = $targetVersion
            if ($j.ContainsKey('packages') -and $j['packages'].ContainsKey('')) {
                $j['packages']['']['version'] = $targetVersion
            }
            $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json -Depth 10 -AsHashtable
        $result['version'] | Should -Be '5.0.0'
        $result['packages']['']['version'] | Should -Be '5.0.0'
        $result['name'] | Should -Be 'hve-core'
    }

    It 'Updates only top-level version when packages[""] is absent' {
        $filePath = Join-Path $script:TempDir 'lock-no-root-pkg.json'
        @{
            name            = 'hve-core'
            version         = '1.0.0'
            lockfileVersion = 3
        } | ConvertTo-Json -Depth 10 | Set-Content $filePath

        $targetVersion = '6.0.0'
        Update-JsonVersion -FilePath $filePath -Description 'package-lock.json' -AsHashtable -Transform {
            param($j)
            $j['version'] = $targetVersion
            if ($j.ContainsKey('packages') -and $j['packages'].ContainsKey('')) {
                $j['packages']['']['version'] = $targetVersion
            }
            $j
        }

        $result = Get-Content -Raw $filePath | ConvertFrom-Json -Depth 10 -AsHashtable
        $result['version'] | Should -Be '6.0.0'
        $result['name'] | Should -Be 'hve-core'
    }

    It 'Throws when file contains malformed JSON' {
        $filePath = Join-Path $script:TempDir 'malformed.json'
        Set-Content -Path $filePath -Value '{ invalid json }'

        { Update-JsonVersion -FilePath $filePath -Description 'malformed' -Transform { param($j) $j } } |
            Should -Throw
    }

    It 'Throws when file is empty' {
        $filePath = Join-Path $script:TempDir 'empty.json'
        Set-Content -Path $filePath -Value ''

        { Update-JsonVersion -FilePath $filePath -Description 'empty' -Transform { param($j) $j } } |
            Should -Throw
    }

    It 'Propagates errors thrown by the transform block' {
        $filePath = Join-Path $script:TempDir 'transform-err.json'
        @{ version = '1.0.0' } | ConvertTo-Json | Set-Content $filePath

        { Update-JsonVersion -FilePath $filePath -Description 'transform-err' -Transform {
            param($j) throw 'deliberate transform error'
        } } | Should -Throw '*deliberate transform error*'
    }

    It 'Throws when file is read-only' -Skip:($IsWindows -eq $false -and (id -u) -eq 0) {
        $filePath = Join-Path $script:TempDir 'readonly.json'
        @{ version = '1.0.0' } | ConvertTo-Json | Set-Content $filePath
        Set-ItemProperty -Path $filePath -Name IsReadOnly -Value $true

        try {
            { Update-JsonVersion -FilePath $filePath -Description 'readonly' -Transform {
                param($j) $j.version = '2.0.0'; $j
            } } | Should -Throw
        }
        finally {
            Set-ItemProperty -Path $filePath -Name IsReadOnly -Value $false
        }
    }
}

Describe 'Update-VersionFiles script execution' -Tag 'Unit' {
    BeforeAll {
        $script:FakeRoot = Join-Path ([System.IO.Path]::GetTempPath()) "uvf-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:FakeRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot '.git') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot 'extension/templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot '.github/plugin') -Force | Out-Null

        # Seed all version file types at 1.0.0
        @{ version = '1.0.0'; name = 'hve-core' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot 'package.json')
        @{ version = '1.0.0' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot 'extension/templates/package.template.json')
        @{
            metadata = @{ version = '1.0.0' }
            plugins  = @(
                @{ version = '1.0.0'; id = 'hve-core'; source = @{ ref = 'plugins-v1.0.0' } }
                @{ version = '1.0.0'; id = 'ado'; source = @{ ref = 'plugins-v1.0.0' } }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:FakeRoot '.github/plugin/marketplace.json')
        @{ '.' = '1.0.0' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot '.release-please-manifest.json')
        @{
            name            = 'hve-core'
            version         = '1.0.0'
            lockfileVersion = 3
            packages        = @{ '' = @{ version = '1.0.0'; name = 'hve-core' } }
        } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:FakeRoot 'package-lock.json')
    }

    AfterAll {
        if (Test-Path $script:FakeRoot) {
            Remove-Item -Recurse -Force $script:FakeRoot
        }
    }

    It 'Updates all version files to the target version' {
        & $script:ScriptPath -Version '2.5.0' -RepoRoot $script:FakeRoot -SkipPluginGenerate

        $pkg = Get-Content -Raw (Join-Path $script:FakeRoot 'package.json') | ConvertFrom-Json
        $pkg.version | Should -Be '2.5.0'
        $pkg.name | Should -Be 'hve-core'

        $tmpl = Get-Content -Raw (Join-Path $script:FakeRoot 'extension/templates/package.template.json') | ConvertFrom-Json
        $tmpl.version | Should -Be '2.5.0'

        $mkt = Get-Content -Raw (Join-Path $script:FakeRoot '.github/plugin/marketplace.json') | ConvertFrom-Json -Depth 10
        $mkt.metadata.version | Should -Be '2.5.0'
        $mkt.plugins[0].version | Should -Be '2.5.0'
        $mkt.plugins[1].version | Should -Be '2.5.0'
        $mkt.plugins[0].source.ref | Should -Be 'plugins-v2.5.0'
        $mkt.plugins[1].source.ref | Should -Be 'plugins-v2.5.0'

        $manifest = Get-Content -Raw (Join-Path $script:FakeRoot '.release-please-manifest.json') | ConvertFrom-Json
        $manifest.'.' | Should -Be '2.5.0'

        $lock = Get-Content -Raw (Join-Path $script:FakeRoot 'package-lock.json') | ConvertFrom-Json -Depth 10 -AsHashtable
        $lock['version'] | Should -Be '2.5.0'
        $lock['packages']['']['version'] | Should -Be '2.5.0'

        foreach ($relativePath in @(
                'package.json',
                'package-lock.json',
                'extension/templates/package.template.json',
                '.github/plugin/marketplace.json',
                '.release-please-manifest.json'
            )) {
            (Get-Content -Raw (Join-Path $script:FakeRoot $relativePath)).EndsWith(
                "`n",
                [System.StringComparison]::Ordinal
            ) | Should -BeTrue
        }
    }

    It 'Succeeds when optional files are missing' {
        $sparseRoot = Join-Path ([System.IO.Path]::GetTempPath()) "uvf-sparse-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $sparseRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sparseRoot '.git') -Force | Out-Null

        # Only create package.json — other files are absent
        @{ version = '1.0.0' } | ConvertTo-Json | Set-Content (Join-Path $sparseRoot 'package.json')

        try {
            { & $script:ScriptPath -Version '3.0.0' -RepoRoot $sparseRoot -SkipPluginGenerate } |
                Should -Not -Throw

            $pkg = Get-Content -Raw (Join-Path $sparseRoot 'package.json') | ConvertFrom-Json
            $pkg.version | Should -Be '3.0.0'
        }
        finally {
            Remove-Item -Recurse -Force $sparseRoot
        }
    }

    It 'Rejects invalid version "<Version>"' -ForEach @(
        @{ Version = 'abc' }
        @{ Version = '1.2' }
        @{ Version = 'v1.2.3' }
    ) {
        { & $script:ScriptPath -Version $Version -RepoRoot $script:FakeRoot -SkipPluginGenerate } |
            Should -Throw
    }
}

Describe 'Release preparation repair' -Tag 'Unit' {
    BeforeAll {
        $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

        function New-PreparedRoot {
            <#
            .SYNOPSIS
            Builds a root in release-please's prepared state.
            .DESCRIPTION
            release-please's json extra-files updater writes bare version values,
            so every version field already carries the new version while the
            catalog still pins the previous plugins-v<version> locator.
            .OUTPUTS
            [string] Prepared root path.
            #>
            [CmdletBinding()]
            [OutputType([string])]
            param()

            $root = Join-Path ([System.IO.Path]::GetTempPath()) "uvf-prepared-$([guid]::NewGuid())"
            New-Item -ItemType Directory -Path (Join-Path $root '.git') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root '.github/plugin') -Force | Out-Null

            @{ version = '3.4.0'; name = 'hve-core' } |
                ConvertTo-Json | Set-Content (Join-Path $root 'package.json')
            @{ '.' = '3.4.0' } |
                ConvertTo-Json | Set-Content (Join-Path $root '.release-please-manifest.json')
            @{
                metadata = @{ version = '3.4.0' }
                plugins  = @(@{ version = '3.4.0'; id = 'hve-core'; source = @{ ref = 'plugins-v3.2.2' } })
            } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $root '.github/plugin/marketplace.json')

            return $root
        }
    }

    It 'Rewrites a stale plugin locator when every bare version is already current' {
        $root = New-PreparedRoot
        try {
            & $script:ScriptPath -Version '3.4.0' -RepoRoot $root -SkipPluginGenerate

            $catalog = Get-Content -Raw (Join-Path $root '.github/plugin/marketplace.json') | ConvertFrom-Json -Depth 10
            $catalog.plugins[0].source.ref | Should -Be 'plugins-v3.4.0'
            $catalog.metadata.version | Should -Be '3.4.0'
            $catalog.plugins[0].version | Should -Be '3.4.0'
        }
        finally {
            Remove-Item -Recurse -Force $root
        }
    }

    It 'Leaves an already-consistent preparation byte-identical' {
        $root = New-PreparedRoot
        try {
            & $script:ScriptPath -Version '3.4.0' -RepoRoot $root -SkipPluginGenerate
            $catalogPath = Join-Path $root '.github/plugin/marketplace.json'
            $first = Get-Content -Raw $catalogPath

            & $script:ScriptPath -Version '3.4.0' -RepoRoot $root -SkipPluginGenerate

            Get-Content -Raw $catalogPath | Should -BeExactly $first
        }
        finally {
            Remove-Item -Recurse -Force $root
        }
    }

    # A lint gate that only fails on a stale locator would block every release.
    # The preparation workflow must call this updater on the release-please
    # branch so the promoted commit is already consistent.
    It 'Is invoked on the release preparation branch by the stable workflow' {
        $workflowPath = Join-Path $script:RepositoryRoot '.github/workflows/release-stable.yml'
        $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding utf8
        $document = $workflow | ConvertFrom-Yaml

        $sync = $document['jobs']['sync-release-pr']
        $sync | Should -Not -BeNullOrEmpty

        $checkout = @($sync['steps'] | Where-Object { $_.Contains('uses') -and [string]$_['uses'] -match '^actions/checkout@' })
        [string]$checkout[0]['with']['ref'] | Should -BeExactly '${{ needs.release-please.outputs.release-pr-branch }}'

        $runs = [string[]]@($sync['steps'] | Where-Object { $_.Contains('run') } | ForEach-Object { [string]$_['run'] })
        $invocation = @($runs | Where-Object { $_ -match 'scripts/release/Update-VersionFiles\.ps1' })
        $invocation | Should -HaveCount 1
        $invocation[0] | Should -Match '-SkipPluginGenerate'
        $invocation[0] | Should -Match 'git push origin "HEAD:refs/heads/\$RELEASE_BRANCH"'
        $invocation[0] | Should -Not -Match 'push --force'
    }
}
