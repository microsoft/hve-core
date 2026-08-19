#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../release/Set-RepositoryVersion.ps1') -Version '0.0.0'
    Mock Write-Host {}

    function New-VersionFixture {
        <#
        .SYNOPSIS
            Builds a repository fixture holding every version-tracked file.
        #>
        param(
            [string]$Root,
            [string]$Version = '1.2.3'
        )

        $files = @{
            'package.json'                              = @"
{
  "metadata": {
    "version": "0.1.0"
  },
  "name": "fixture",
  "version": "$Version",
  "private": true,
  "devDependencies": {
    "left-pad": "1.2.3"
  }
}
"@
            'package-lock.json'                         = @"
{
  "name": "fixture",
  "version": "$Version",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "fixture",
      "version": "$Version",
      "license": "MIT",
      "devDependencies": {
        "left-pad": "1.2.3"
      }
    },
    "node_modules/left-pad": {
      "version": "1.2.3",
      "resolved": "https://registry.npmjs.org/left-pad/-/left-pad-1.2.3.tgz"
    }
  }
}
"@
            'extension/templates/package.template.json' = @"
{
  "name": "hve-core",
  "displayName": "HVE Core",
  "version": "$Version",
  "publisher": "ise-hve-essentials"
}
"@
            'plugin.json'                               = @"
{
  "name": "hve-core",
  "description": "Fixture plugin",
  "version": "$Version",
  "agents": [],
  "commands": [],
  "rules": [],
  "skills": [],
  "hooks": "hooks/shared/telemetry.json"
}
"@
            '.github/plugin/marketplace.json'           = @"
{
  "name": "hve-core",
  "metadata": {
    "description": "HVE Core",
    "version": "$Version"
  },
  "owner": {
    "name": "Microsoft"
  },
  "plugins": [
    {
      "name": "hve-core",
    "source": ".",
      "description": "Fixture plugin",
      "version": "$Version"
    }
  ]
}
"@
            '.release-please-manifest.json'             = @"
{
  ".": "$Version"
}
"@
        }

        foreach ($relative in $files.Keys) {
            $path = Join-Path $Root $relative
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            Set-Content -LiteralPath $path -Value ($files[$relative] + "`n") -Encoding UTF8 -NoNewline
        }

        return $Root
    }

    function Get-FixtureInventory {
        <#
        .SYNOPSIS
            Maps every fixture file to its content hash.
        #>
        param([string]$Root)

        $inventory = [ordered]@{}
        foreach ($file in (Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName)) {
            $relative = $file.FullName.Substring($Root.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
            $inventory[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
        return $inventory
    }
}

Describe 'Set-RepositoryVersion' -Tag 'Unit' {
    Context 'when applying a new version' {
        BeforeAll {
            $script:Root = New-VersionFixture -Root (Join-Path $TestDrive 'apply')
            $script:Before = Get-FixtureInventory -Root $script:Root
            $script:Result = Set-RepositoryVersion -RepoRoot $script:Root -Version '3.3.0'
            $script:After = Get-FixtureInventory -Root $script:Root
        }

        It 'Updates <Path> <Member>' -ForEach @(
            @{ Path = 'package.json'; Member = '$.version'; Expected = '3.3.0' }
            @{ Path = 'package-lock.json'; Member = '$.version'; Expected = '3.3.0' }
            @{ Path = 'package-lock.json'; Member = '$.packages[""].version'; Expected = '3.3.0' }
            @{ Path = 'extension/templates/package.template.json'; Member = '$.version'; Expected = '3.3.0' }
            @{ Path = 'plugin.json'; Member = '$.version'; Expected = '3.3.0' }
            @{ Path = '.github/plugin/marketplace.json'; Member = '$.metadata.version'; Expected = '3.3.0' }
            @{ Path = '.github/plugin/marketplace.json'; Member = '$.plugins[0].version'; Expected = '3.3.0' }
        ) {
            $json = Get-Content -LiteralPath (Join-Path $script:Root $Path) -Raw | ConvertFrom-Json -AsHashtable
            Get-JsonMemberValue -Json $json -Path $Member | Should -BeExactly $Expected
        }

        It 'Reports every version-tracked file as changed' {
            @($script:Result | Where-Object { $_.Changed }) | Should -HaveCount 5
        }

        It 'Leaves dependency versions in the lockfile untouched' {
            $lock = Get-Content -LiteralPath (Join-Path $script:Root 'package-lock.json') -Raw | ConvertFrom-Json -AsHashtable
            $lock['packages']['']['devDependencies']['left-pad'] | Should -BeExactly '1.2.3'
            $lock['packages']['node_modules/left-pad']['version'] | Should -BeExactly '1.2.3'
        }

        It 'Leaves an earlier nested package version untouched' {
            $package = Get-Content -LiteralPath (Join-Path $script:Root 'package.json') -Raw | ConvertFrom-Json
            $package.metadata.version | Should -BeExactly '0.1.0'
        }

        It 'Leaves <Path> unchanged' -ForEach @(
            @{ Path = '.release-please-manifest.json' }
        ) {
            $script:After[$Path] | Should -BeExactly $script:Before[$Path]
        }

        It 'Creates and removes no files' {
            @($script:After.Keys) | Should -Be @($script:Before.Keys)
        }

        It 'Adds no source ref to the catalog entry' {
            $catalog = Get-Content -LiteralPath (Join-Path $script:Root '.github/plugin/marketplace.json') -Raw | ConvertFrom-Json -AsHashtable
            @($catalog['plugins'])[0]['source'] | Should -BeExactly '.'
        }

        It 'Keeps the catalog at one entry' {
            $catalog = Get-Content -LiteralPath (Join-Path $script:Root '.github/plugin/marketplace.json') -Raw | ConvertFrom-Json -AsHashtable
            @($catalog['plugins']) | Should -HaveCount 1
        }
    }

    Context 'when reapplying the same version' {
        BeforeAll {
            $script:IdempotentRoot = New-VersionFixture -Root (Join-Path $TestDrive 'idempotent')
            Set-RepositoryVersion -RepoRoot $script:IdempotentRoot -Version '3.3.0' | Out-Null
            $script:FirstPass = Get-FixtureInventory -Root $script:IdempotentRoot
            $script:SecondResult = Set-RepositoryVersion -RepoRoot $script:IdempotentRoot -Version '3.3.0'
        }

        It 'Reports no file as changed' {
            @($script:SecondResult | Where-Object { $_.Changed }) | Should -HaveCount 0
        }

        It 'Produces byte-identical files' {
            Get-FixtureInventory -Root $script:IdempotentRoot | ConvertTo-Json |
                Should -BeExactly ($script:FirstPass | ConvertTo-Json)
        }
    }

    Context 'when the repository shape is unexpected' {
        It 'Throws when a version-tracked file is missing' {
            $root = New-VersionFixture -Root (Join-Path $TestDrive 'missing')
            Remove-Item -LiteralPath (Join-Path $root 'plugin.json') -Force

            { Set-RepositoryVersion -RepoRoot $root -Version '3.3.0' } |
                Should -Throw '*Version-tracked file not found: plugin.json*'
        }

        It 'Rejects a version that is not three numeric segments' {
            $root = New-VersionFixture -Root (Join-Path $TestDrive 'invalid')

            { Set-RepositoryVersion -RepoRoot $root -Version '3.3' } | Should -Throw
        }

        It 'Writes no file when a later target member is missing' {
            $root = New-VersionFixture -Root (Join-Path $TestDrive 'atomic-failure')
            $catalogPath = Join-Path $root '.github/plugin/marketplace.json'
            $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -AsHashtable
            $catalog['metadata'].Remove('version')
            $catalog | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $catalogPath -Encoding utf8NoBOM
            $before = Get-FixtureInventory -Root $root

            { Set-RepositoryVersion -RepoRoot $root -Version '3.3.0' } |
                Should -Throw "Member location 'metadata.version' has no member 'version'."

            Get-FixtureInventory -Root $root | ConvertTo-Json |
                Should -BeExactly ($before | ConvertTo-Json)
        }
    }
}

Describe 'Set-JsonMemberValue' -Tag 'Unit' {
    It 'Throws when the exact member is absent' {
        { Set-JsonMemberValue -Content '{ "name": "fixture" }' -Location @('version') -Value '3.3.0' } |
            Should -Throw "Member location 'version' has no member 'version'."
    }

    It 'Selects the top-level member when a nested member precedes it' {
        $content = '{ "nested": { "version": "1.0.0" }, "version": "2.0.0" }'
        Set-JsonMemberValue -Content $content -Location @('version') -Value '3.3.0' |
            Should -BeExactly '{ "nested": { "version": "1.0.0" }, "version": "3.3.0" }'
    }

    It 'Replaces only the captured value' {
        $content = "{`n  `"version`": `"1.0.0`",`n  `"other`": `"1.0.0`"`n}"
        Set-JsonMemberValue -Content $content -Location @('version') -Value '3.3.0' |
            Should -BeExactly "{`n  `"version`": `"3.3.0`",`n  `"other`": `"1.0.0`"`n}"
    }
}
