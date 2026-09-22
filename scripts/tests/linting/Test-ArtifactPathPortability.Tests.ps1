#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Test-ArtifactPathPortability.ps1'
    . $script:ScriptPath

    function New-PortableArtifactFixture {
        param(
            [string]$RepoRoot,
            [string]$RelativePath,
            [AllowEmptyString()]
            [string]$Content = '# Fixture'
        )

        $path = Join-Path $RepoRoot $RelativePath
        New-Item -ItemType Directory -Path (Split-Path -Path $path -Parent) -Force | Out-Null
        Set-Content -LiteralPath $path -Value $Content -Encoding utf8NoBOM
        return $path
    }
}

Describe 'Test-ArtifactPathPortability classification' -Tag 'Unit' {
    It 'Reports operational prose, path tables, skill navigation, and prefixed directives' -ForEach @(
        @{ Content = 'Read `.github/instructions/shared/example.instructions.md` before continuing.' }
        @{ Content = '| Source | .github/agents/example/worker.agent.md |' }
        @{ Content = 'Load the schema from `.github/skills/example/sample/references/schema.md`.' }
        @{ Content = '#file:.github/instructions/shared/example.instructions.md' }
    ) {
        $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/fixture.agent.md' -Content $Content

        $result = Test-ArtifactPathPortability -RepoRoot $repo

        $result.Passed | Should -BeFalse
        $result.Findings | Should -HaveCount 1
        $result.Findings[0].File | Should -Be '.github/agents/example/fixture.agent.md'
        $result.Findings[0].Line | Should -Be 1
        $result.Findings[0].Reference | Should -Match '\.github/'
        $result.Findings[0].Reason | Should -Not -BeNullOrEmpty
    }

    It 'Ignores sanctioned syntax and demonstrably descriptive masked regions' {
        $repo = Join-Path $TestDrive 'sanctioned'
        $content = @'
---
applyTo: '.github/agents/example/*.agent.md'
---
# Fixture

```text
Read .github/instructions/example.instructions.md
```

[.github/instructions/example.instructions.md](../../instructions/example.instructions.md)
[portable](../../../.github/instructions/example.instructions.md)
Dispatch `.github/agents/**/worker.agent.md`.
Use `.github/skills/<package>/<skill>/SKILL.md`.
Use `.github/skills/{package}/{skill}/references/file.md`.
'@
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/fixture.agent.md' -Content $content

        $result = Test-ArtifactPathPortability -RepoRoot $repo

        $result.Passed | Should -BeTrue
        $result.Findings | Should -HaveCount 0
    }

    It 'Reports commands in operational shell fences' -ForEach @(
        @{ Fence = 'bash'; Command = 'python .github/skills/example/scripts/run.py'; Reference = '.github/skills/example/scripts/run.py' }
        @{ Fence = 'sh'; Command = 'cd .github/skills/example'; Reference = '.github/skills/example' }
        @{ Fence = 'shell'; Command = 'uv run --project .github/skills/example pytest'; Reference = '.github/skills/example' }
        @{ Fence = 'powershell'; Command = './.github/skills/example/scripts/Invoke-Example.ps1'; Reference = './.github/skills/example/scripts/Invoke-Example.ps1' }
        @{ Fence = 'pwsh title="Example"'; Command = './.github/skills/example/scripts/Invoke-Example.ps1'; Reference = './.github/skills/example/scripts/Invoke-Example.ps1' }
        @{ Fence = 'console'; Command = 'python .github/skills/example/scripts/run.py'; Reference = '.github/skills/example/scripts/run.py' }
    ) {
        $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $content = "``````$Fence`n$Command`n``````"
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/fixture.agent.md' -Content $content

        $result = Test-ArtifactPathPortability -RepoRoot $repo

        $result.Passed | Should -BeFalse
        $result.Findings | Should -HaveCount 1
        $result.Findings[0].Line | Should -Be 2
        $result.Findings[0].Reference | Should -Be $Reference
    }

    It 'Reports an optional dot-slash prefix outside a fence' {
        $repo = Join-Path $TestDrive 'dot-slash'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/fixture.agent.md' -Content 'Run ./.github/skills/example/scripts/Invoke-Example.ps1.'

        $result = Test-ArtifactPathPortability -RepoRoot $repo

        $result.Passed | Should -BeFalse
        $result.Findings | Should -HaveCount 1
        $result.Findings[0].Reference | Should -Be './.github/skills/example/scripts/Invoke-Example.ps1'
    }

    It 'Allows only the exact persisted provenance literal in its approved files' {
        $repo = Join-Path $TestDrive 'provenance'
        $literal = 'source: .github/skills/rai/rai-standards/SKILL.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/rai-planning/rai-planner.agent.md' -Content $literal
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/instructions/rai-planning/rai-identity.instructions.md' -Content $literal
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/fixture.agent.md' -Content $literal

        $result = Test-ArtifactPathPortability -RepoRoot $repo

        $result.Passed | Should -BeFalse
        $result.Findings | Should -HaveCount 1
        $result.Findings[0].File | Should -Be '.github/agents/example/fixture.agent.md'
    }
}

Describe 'Test-ArtifactPathPortability corpus' -Tag 'Unit' {
    It 'Scans direct artifacts and expands skill runtime references' {
        $repo = Join-Path $TestDrive 'expanded'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/fixture.agent.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/prompts/example/fixture.prompt.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/instructions/example/fixture.instructions.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/skills/example/sample/SKILL.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/skills/example/sample/references/nested/reference.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/skills/example/sample/assets/ignored.md'

        $result = Test-ArtifactPathPortability -RepoRoot $repo

        $result.ScannedFileCount | Should -Be 5
    }

    It 'Excludes repository-only, deprecated, installer, Vally evidence, and hook artifacts' {
        $repo = Join-Path $TestDrive 'excluded'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/included.agent.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/root.agent.md' -Content 'Read .github/bad.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/deprecated/old.agent.md' -Content 'Read .github/bad.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/skills/installer/sample/SKILL.md' -Content 'Read .github/bad.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/skills/hve-core/vally-tests/SKILL.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/skills/hve-core/vally-tests/references/agents.md' -Content 'Evidence: .github/bad.md'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/hooks/example/hooks.json' -Content '{}'

        $result = Test-ArtifactPathPortability -RepoRoot $repo

        $result.Passed | Should -BeTrue
        $result.ScannedFileCount | Should -Be 2
    }

    It 'Returns findings in deterministic file, line, and reference order' {
        $repo = Join-Path $TestDrive 'ordered'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/z.agent.md' -Content "Read .github/z.md.`nRead .github/a.md."
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/a.agent.md' -Content 'Read .github/b.md.'

        $result = Test-ArtifactPathPortability -RepoRoot $repo

        @($result.Findings.File) | Should -Be @(
            '.github/agents/example/a.agent.md'
            '.github/agents/example/z.agent.md'
            '.github/agents/example/z.agent.md'
        )
        @($result.Findings.Line) | Should -Be @(1, 1, 2)
    }

    It 'Writes JSON and exits nonzero when findings exist' {
        $repo = Join-Path $TestDrive 'process-failure'
        $output = Join-Path $repo 'logs/result.json'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/fixture.agent.md' -Content 'Read .github/bad.md.'

        & pwsh -NoProfile -File $script:ScriptPath -RepoRoot $repo -OutputPath $output *> $null

        $LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $output | Should -BeTrue
        $json = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
        $json.Passed | Should -BeFalse
        $json.Findings | Should -HaveCount 1
    }

    It 'Writes JSON and exits zero for a portable corpus' {
        $repo = Join-Path $TestDrive 'process-success'
        $output = Join-Path $repo 'logs/result.json'
        New-PortableArtifactFixture -RepoRoot $repo -RelativePath '.github/agents/example/fixture.agent.md'

        & pwsh -NoProfile -File $script:ScriptPath -RepoRoot $repo -OutputPath $output *> $null

        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath $output | Should -BeTrue
        $json = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
        $json.Passed | Should -BeTrue
        $json.ScannedFileCount | Should -Be 1
    }
}
