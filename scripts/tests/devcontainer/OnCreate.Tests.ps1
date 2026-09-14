#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:OnCreatePath = Join-Path $script:RepoRoot '.devcontainer/scripts/on-create.sh'
    $script:CopilotSetupPath = Join-Path $script:RepoRoot '.github/workflows/copilot-setup-steps.yml'
    $script:BashCommand = Get-Command bash -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1

    function ConvertTo-BashLiteral {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Value
        )

        return "'$Value'"
    }

    function New-TestPythonProject {
        [CmdletBinding()]
        [OutputType([void])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $false)]
            [switch]$WithoutLock,

            [Parameter(Mandatory = $false)]
            [string]$IndexUrl
        )

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        $projectContent = @('[project]')
        if ($IndexUrl) {
            $projectContent += @(
                '',
                '[[tool.uv.index]]',
                'name = "project-index"',
                "url = `"$IndexUrl`""
            )
        }
        Set-Content -Path (Join-Path $Path 'pyproject.toml') -Value $projectContent
        if (-not $WithoutLock) {
            Set-Content -Path (Join-Path $Path 'uv.lock') -Value 'version = 1'
        }
    }

    function Invoke-TestPythonSync {
        [CmdletBinding()]
        [OutputType([int])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$TestRepo,

            [Parameter(Mandatory = $true)]
            [string]$StubDirectory,

            [Parameter(Mandatory = $true)]
            [string]$CallLog,

            [Parameter(Mandatory = $false)]
            [string]$FailDirectory,

            [Parameter(Mandatory = $false)]
            [string]$DefaultIndex = 'https://pypi.org/simple'
        )

        $originalPath = $env:PATH
        $originalCallLog = $env:UV_CALL_LOG
        $originalFailDirectory = $env:UV_FAIL_DIR
        $originalDefaultIndex = $env:UV_DEFAULT_INDEX
        try {
            $env:PATH = "$StubDirectory$([System.IO.Path]::PathSeparator)$originalPath"
            $env:UV_CALL_LOG = $CallLog
            $env:UV_FAIL_DIR = $FailDirectory
            $env:UV_DEFAULT_INDEX = $DefaultIndex
            $command = "source $(ConvertTo-BashLiteral $script:OnCreatePath); sync_python_environments $(ConvertTo-BashLiteral $TestRepo)"
            & $script:BashCommand.Source -c $command | Out-Null
            $exitCode = $LASTEXITCODE
            return $exitCode
        }
        finally {
            $env:PATH = $originalPath
            $env:UV_CALL_LOG = $originalCallLog
            $env:UV_FAIL_DIR = $originalFailDirectory
            $env:UV_DEFAULT_INDEX = $originalDefaultIndex
        }
    }

    function New-UvStub {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Directory
        )

        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        $stubPath = Join-Path $Directory 'uv'
        $stubContent = @(
            '#!/usr/bin/env bash'
            'printf ''%s|%s\n'' "${PWD}" "$*" >> "${UV_CALL_LOG}"'
            'if [[ -n "${UV_FAIL_DIR:-}" && "${PWD}" == *"${UV_FAIL_DIR}" ]]; then'
            '  exit 42'
            'fi'
        ) -join "`n"
        [System.IO.File]::WriteAllText(
            $stubPath,
            "$stubContent`n",
            [System.Text.UTF8Encoding]::new($false)
        )
        & chmod +x $stubPath
        return $stubPath
    }
}

Describe 'on-create Python environment sync contract' -Tag 'Unit' {
    Context 'Source safety and workflow reuse' {
        It 'Guards main so the sync function can be sourced without running setup' {
            $content = Get-Content -Path $script:OnCreatePath -Raw

            $content | Should -Match 'function sync_python_environments|sync_python_environments\(\)'
            $content | Should -Match 'BASH_SOURCE\[0\].*\$0'
            $content | Should -Match 'sync_python_project "scripts/evals/moderation"'
            $content | Should -Not -Match 'cd scripts/evals/moderation.*uv sync --locked'
        }

        It 'Makes the coding-agent setup call the shared sync function' {
            $content = Get-Content -Path $script:CopilotSetupPath -Raw

            $content | Should -Match 'source \.devcontainer/scripts/on-create\.sh'
            $content | Should -Match 'sync_python_environments "\$\{GITHUB_WORKSPACE\}"'
        }
    }

    Context 'Bash execution' {
        BeforeEach {
            if ($IsWindows -or -not $script:BashCommand) {
                return
            }

            $testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $script:TestRepo = Join-Path $testRoot 'repo'
            $script:StubDirectory = Join-Path $testRoot 'bin'
            $script:CallLog = Join-Path $testRoot 'uv-calls.log'
            New-Item -ItemType Directory -Path $script:TestRepo -Force | Out-Null
            New-UvStub -Directory $script:StubDirectory | Out-Null
        }

        It 'Syncs every eligible project with locked arguments and excludes non-lint projects' {
            if ($IsWindows -or -not $script:BashCommand) {
                Set-ItResult -Skipped -Because 'authoritative Bash execution runs on Ubuntu'
                return
            }

            New-TestPythonProject -Path (Join-Path $script:TestRepo '.github/skills/sample skill')
            New-TestPythonProject -Path (Join-Path $script:TestRepo '.github/hooks/shared/telemetry')
            New-TestPythonProject -Path (Join-Path $script:TestRepo 'scripts/evals/moderation')
            New-TestPythonProject -Path (Join-Path $script:TestRepo 'plugins/generated/skill')
            New-TestPythonProject -Path (Join-Path $script:TestRepo 'node_modules/package')

            $exitCode = Invoke-TestPythonSync -TestRepo $script:TestRepo -StubDirectory $script:StubDirectory -CallLog $script:CallLog
            $calls = @(Get-Content -Path $script:CallLog)

            $exitCode | Should -Be 0
            $calls | Should -HaveCount 2
            ($calls -join "`n") | Should -Match 'sample skill\|sync --locked'
            ($calls -join "`n") | Should -Match 'hooks/shared/telemetry\|sync --locked'
            ($calls -join "`n") | Should -Not -Match 'moderation|plugins/generated|node_modules'
        }

        It 'Installs locked hashes through a custom default index without relocking' {
            if ($IsWindows -or -not $script:BashCommand) {
                Set-ItResult -Skipped -Because 'authoritative Bash execution runs on Ubuntu'
                return
            }

            New-TestPythonProject `
                -Path (Join-Path $script:TestRepo '.github/skills/mirrored-project') `
                -IndexUrl 'https://project.example.com/simple'

            $exitCode = Invoke-TestPythonSync `
                -TestRepo $script:TestRepo `
                -StubDirectory $script:StubDirectory `
                -CallLog $script:CallLog `
                -DefaultIndex 'https://mirror.example.com/pypi/simple'
            $calls = @(Get-Content -Path $script:CallLog)

            $exitCode | Should -Be 0
            $calls | Should -HaveCount 3
            $calls[0] | Should -Match 'mirrored-project\|export --locked --offline --no-emit-project --quiet --output-file '
            $calls[1] | Should -Match 'mirrored-project\|venv \.venv'
            $calls[2] | Should -Match 'mirrored-project\|pip sync --python \.venv/bin/python --require-hashes --default-index https://mirror\.example\.com/pypi/simple --index https://mirror\.example\.com/pypi/simple --index https://project\.example\.com/simple --index-strategy unsafe-first-match '
            ($calls -join "`n") | Should -Not -Match 'sync --locked'
        }

        It 'Returns nonzero after a child sync fails and still processes other projects' {
            if ($IsWindows -or -not $script:BashCommand) {
                Set-ItResult -Skipped -Because 'authoritative Bash execution runs on Ubuntu'
                return
            }

            New-TestPythonProject -Path (Join-Path $script:TestRepo '.github/skills/failing-project')
            New-TestPythonProject -Path (Join-Path $script:TestRepo '.github/skills/passing-project')

            $exitCode = Invoke-TestPythonSync -TestRepo $script:TestRepo -StubDirectory $script:StubDirectory -CallLog $script:CallLog -FailDirectory 'failing-project'
            $calls = @(Get-Content -Path $script:CallLog)

            $exitCode | Should -Be 1
            $calls | Should -HaveCount 2
        }

        It 'Returns nonzero for an eligible project without a lockfile' {
            if ($IsWindows -or -not $script:BashCommand) {
                Set-ItResult -Skipped -Because 'authoritative Bash execution runs on Ubuntu'
                return
            }

            New-TestPythonProject -Path (Join-Path $script:TestRepo '.github/skills/missing-lock') -WithoutLock

            $exitCode = Invoke-TestPythonSync -TestRepo $script:TestRepo -StubDirectory $script:StubDirectory -CallLog $script:CallLog

            $exitCode | Should -Be 1
            Test-Path $script:CallLog | Should -BeFalse
        }
    }
}
