#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../security/Test-PublicDependencyFeeds.ps1'
    . $script:ScriptPath

    function New-PublicFeedTestRepository {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $false)]
            [hashtable]$Files = @{}
        )

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        & git -C $Path init --quiet
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to initialize the dependency feed test repository.'
        }

        foreach ($relativePath in $Files.Keys) {
            $fullPath = Join-Path $Path $relativePath
            $parent = Split-Path -Parent $fullPath
            if ($parent) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Set-Content -LiteralPath $fullPath -Value $Files[$relativePath] -Encoding utf8
        }
    }
}

Describe 'Test-DependencySourceLine' -Tag 'Unit' {
    It 'Returns <Expected> for <Path>' -ForEach @(
        @{ Path = 'package.json'; Line = '"registry": "https://registry.npmjs.org/"'; Expected = $true }
        @{ Path = 'package.json'; Line = '"tool": "https://github.com/example/tool.git"'; Expected = $true }
        @{ Path = 'package.json'; Line = '"tool": "git+https://github.com/example/tool.git"'; Expected = $true }
        @{ Path = 'package.json'; Line = '"tool": "1.0.0"'; Expected = $false }
        @{ Path = 'package-lock.json'; Line = '"resolved": "https://registry.npmjs.org/tool/-/tool-1.0.0.tgz"'; Expected = $true }
        @{ Path = 'npm-shrinkwrap.json'; Line = '"integrity": "sha512-value"'; Expected = $true }
        @{ Path = '.npmrc'; Line = '@scope:registry=https://registry.npmjs.org/'; Expected = $true }
        @{ Path = '.npmrc'; Line = 'save-exact=true'; Expected = $false }
        @{ Path = 'uv.lock'; Line = 'registry = "https://pypi.org/simple"'; Expected = $true }
        @{ Path = 'uv.lock'; Line = 'version = 1'; Expected = $false }
        @{ Path = 'pyproject.toml'; Line = 'index-url = "https://pypi.org/simple"'; Expected = $true }
        @{ Path = 'pyproject.toml'; Line = 'requires-python = ">=3.11"'; Expected = $false }
        @{ Path = 'requirements-dev.txt'; Line = '--extra-index-url https://pypi.org/simple'; Expected = $true }
        @{ Path = 'requirements.txt'; Line = 'pytest==9.0.0'; Expected = $false }
        @{ Path = 'unknown.yml'; Line = 'url: https://example.com'; Expected = $false }
    ) {
        Test-DependencySourceLine -Path $Path -Line $Line | Should -Be $Expected
    }
}

Describe 'Invoke-PublicDependencyFeedScan' -Tag 'Unit' {
    It 'Returns no violations for an empty repository' {
        $repoRoot = Join-Path $TestDrive 'empty'
        New-PublicFeedTestRepository -Path $repoRoot

        $result = Invoke-PublicDependencyFeedScan -RepoRoot $repoRoot

        $result.violationCount | Should -Be 0
        $result.filesScanned | Should -Be 0
    }

    It 'Reports <Reason> for <FileName>' -ForEach @(
        @{
            FileName = 'package-lock.json'
            Content = '{ "integrity": "sha1-value" }'
            Reason = 'lockfile integrity must use sha512'
        }
        @{
            FileName = 'requirements.txt'
            Content = 'tool @ https://private-feed.example.com/packaging/tool.whl'
            Reason = 'not an approved public registry'
        }
        @{
            FileName = 'requirements.txt'
            Content = 'tool @ http://pypi.org/example/tool.whl'
            Reason = 'must use HTTPS'
        }
        @{
            FileName = 'requirements.txt'
            Content = 'tool @ https://user:pass@pypi.org/example/tool.whl'
            Reason = 'must not contain credentials'
        }
        @{
            FileName = '.npmrc'
            Content = 'registry=https://example.com/'
            Reason = 'must use https://registry.npmjs.org/'
        }
        @{
            FileName = '.npmrc'
            Content = 'registry=${NPM_REGISTRY}'
            Reason = 'must be literal public HTTPS URLs'
        }
        @{
            FileName = 'requirements.txt'
            Content = 'tool @ https://%'
            Reason = 'dependency source URL is invalid'
        }
    ) {
        $repoRoot = Join-Path $TestDrive ([IO.Path]::GetRandomFileName())
        New-PublicFeedTestRepository -Path $repoRoot -Files @{ $FileName = $Content }

        $result = Invoke-PublicDependencyFeedScan -RepoRoot $repoRoot

        $result.violationCount | Should -Be 1
        $result.violations[0].reason | Should -Match ([regex]::Escape($Reason))
    }

    It 'Accepts approved public hosts' {
        $repoRoot = Join-Path $TestDrive 'approved-hosts'
        New-PublicFeedTestRepository -Path $repoRoot -Files @{
            'requirements.txt' = @(
                'npm @ https://registry.npmjs.org/npm/-/npm-1.0.0.tgz'
                'project @ https://pypi.org/project/project/'
                'wheel @ https://files.pythonhosted.org/packages/project.whl'
                'crate @ https://crates.io/api/v1/crates/example/1.0.0/download'
            )
        }

        $result = Invoke-PublicDependencyFeedScan -RepoRoot $repoRoot

        $result.violationCount | Should -Be 0
        $result.sourcesValidated | Should -Be 4
    }
}

Describe 'Test-PublicDependencyFeeds main execution' -Tag 'Unit' {
    It 'Writes results and exits zero for a clean repository' {
        $repoRoot = Join-Path $TestDrive 'main-clean'
        $outputPath = Join-Path $TestDrive 'clean-results.json'
        New-PublicFeedTestRepository -Path $repoRoot -Files @{
            '.npmrc' = 'registry=https://registry.npmjs.org/'
        }

        & (Get-Process -Id $PID).Path -NoProfile -File $script:ScriptPath -RepoRoot $repoRoot -OutputPath $outputPath -FailOnViolation *> $null

        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath $outputPath | Should -BeTrue
        (Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json).violationCount | Should -Be 0
    }

    It 'Writes results and exits one for a prohibited source' {
        $repoRoot = Join-Path $TestDrive 'main-violation'
        $outputPath = Join-Path $TestDrive 'violation-results.json'
        New-PublicFeedTestRepository -Path $repoRoot -Files @{
            '.npmrc' = 'registry=https://private-feed.example.com/packaging/'
        }

        & (Get-Process -Id $PID).Path -NoProfile -File $script:ScriptPath -RepoRoot $repoRoot -OutputPath $outputPath -FailOnViolation *> $null

        $LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $outputPath | Should -BeTrue
        (Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json).violationCount | Should -Be 1
    }
}