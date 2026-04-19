#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
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
            $Path -like "*../..*"
        }
        Mock Test-Path { return $false } -ParameterFilter {
            $Path -like "*/.git"
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
        New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot 'plugins/hve-core/.github/plugin') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:FakeRoot 'plugins/ado/.github/plugin') -Force | Out-Null

        # Seed all 5 version file types at 1.0.0
        @{ version = '1.0.0'; name = 'hve-core' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot 'package.json')
        @{ version = '1.0.0' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot 'extension/templates/package.template.json')
        @{
            metadata = @{ version = '1.0.0' }
            plugins  = @(
                @{ version = '1.0.0'; id = 'hve-core' }
                @{ version = '1.0.0'; id = 'ado' }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:FakeRoot '.github/plugin/marketplace.json')
        @{ version = '1.0.0' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot 'plugins/hve-core/.github/plugin/plugin.json')
        @{ version = '1.0.0' } |
            ConvertTo-Json | Set-Content (Join-Path $script:FakeRoot 'plugins/ado/.github/plugin/plugin.json')
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

        $manifest = Get-Content -Raw (Join-Path $script:FakeRoot '.release-please-manifest.json') | ConvertFrom-Json
        $manifest.'.' | Should -Be '2.5.0'

        $lock = Get-Content -Raw (Join-Path $script:FakeRoot 'package-lock.json') | ConvertFrom-Json -Depth 10 -AsHashtable
        $lock['version'] | Should -Be '2.5.0'
        $lock['packages']['']['version'] | Should -Be '2.5.0'
    }

    It 'Updates multiple plugin.json files under plugins/' {
        $p1 = Get-Content -Raw (Join-Path $script:FakeRoot 'plugins/hve-core/.github/plugin/plugin.json') | ConvertFrom-Json
        $p1.version | Should -Be '2.5.0'

        $p2 = Get-Content -Raw (Join-Path $script:FakeRoot 'plugins/ado/.github/plugin/plugin.json') | ConvertFrom-Json
        $p2.version | Should -Be '2.5.0'
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
