#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-ArtifactModeration.ps1'
    $script:OrigPath = $env:PATH

    function New-PythonStub {
        param(
            [Parameter(Mandatory)][string]$OutputJson
        )
        $stubDir = Join-Path $TestDrive ("stub-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stubDir -Force | Out-Null

        $stubScript = Join-Path $stubDir 'python.ps1'
        $jsonLiteral = $OutputJson.Replace("'", "''")
@"
param([Parameter(ValueFromRemainingArguments=`$true)]`$Args)
`$outIndex = [Array]::IndexOf(`$Args, '--output')
if (`$outIndex -lt 0) { exit 2 }
`$outPath = `$Args[`$outIndex + 1]
Set-Content -LiteralPath `$outPath -Value '$jsonLiteral' -Encoding utf8 -NoNewline
`$json = '$jsonLiteral' | ConvertFrom-Json
if (`$json.summary.flaggedCount -gt 0) { exit 1 } else { exit 0 }
"@ | Set-Content -LiteralPath $stubScript -Encoding utf8 -NoNewline

        if ($IsWindows) {
            $shim = Join-Path $stubDir 'python.cmd'
            "@pwsh -NoProfile -File `"$stubScript`" %*" | Set-Content -LiteralPath $shim -Encoding ascii -NoNewline
        }
        else {
            # `.cmd` shims are not honored by PATH lookups on Linux/macOS CI, so
            # emit an extensionless executable that `Get-Command python` resolves.
            $shim = Join-Path $stubDir 'python'
            "#!/usr/bin/env sh`npwsh -NoProfile -File `"$stubScript`" `"`$@`"`n" | Set-Content -LiteralPath $shim -Encoding ascii -NoNewline
            & chmod +x $shim
        }
        return $stubDir
    }

    function New-Manifest {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter()][object[]]$Artifacts = @()
        )
        $payload = @{
            artifacts = @($Artifacts)
        }
        $dir = Split-Path $Path -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding utf8 -NoNewline
    }

    function New-Repo {
        $repo = Join-Path $TestDrive ("repo-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        return $repo
    }

    function New-EvalSpec {
        param(
            [Parameter(Mandatory)][string]$RepoRoot,
            [Parameter(Mandatory)][string]$RelativePath
        )
        $full = Join-Path $RepoRoot $RelativePath
        $dir = Split-Path $full -Parent
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $full -Value "category: skill-quality`nname: example" -Encoding utf8 -NoNewline
        return $full
    }
}

Describe 'Invoke-ArtifactModeration.ps1' -Tag 'Unit' {
    AfterEach {
        $env:PATH = $script:OrigPath
        Remove-Item Env:HVE_MODERATION_PYTHON -ErrorAction SilentlyContinue
    }

    It 'Exits 2 when the eval root does not exist' {
        $repo = New-Repo
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-artifacts.json'

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -EvalRoot 'does-not-exist' -OutFile $outFile -RepoRoot $repo 2>$null
        $LASTEXITCODE | Should -Be 2
    }

    It 'Writes empty artifacts result and exits 0 when no specs or artifacts exist' {
        $repo = New-Repo
        New-Item -ItemType Directory -Path (Join-Path $repo 'evals') -Force | Out-Null
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-artifacts.json'

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -EvalRoot 'evals' -OutFile $outFile -RepoRoot $repo 3>$null
        $LASTEXITCODE | Should -Be 0
        Test-Path $outFile | Should -BeTrue
        $data = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
        $data.scope | Should -Be 'artifacts'
        $data.flagged | Should -BeFalse
        $data.results.Count | Should -Be 0
    }

    It 'Moderates eval specs only and exits 0 when the manifest is missing' {
        $repo = New-Repo
        New-EvalSpec -RepoRoot $repo -RelativePath 'evals/skill-quality/example.eval.yaml' | Out-Null
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-artifacts.json'

        $stubDir = New-PythonStub -OutputJson '{"records":[{"id":"evals/skill-quality/example.eval.yaml","scores":{"toxicity":0.02},"flagged":false,"flaggedLabels":[]}],"summary":{"total":1,"flaggedCount":0}}'
        $env:PATH = "$stubDir$([System.IO.Path]::PathSeparator)$($script:OrigPath)"
        $env:HVE_MODERATION_PYTHON = 'python'

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -EvalRoot 'evals' -OutFile $outFile -RepoRoot $repo 3>$null
        $LASTEXITCODE | Should -Be 0
        Test-Path $outFile | Should -BeTrue
    }

    It 'Skips deleted artifacts and exits 0 when nothing remains to moderate' {
        $repo = New-Repo
        New-Item -ItemType Directory -Path (Join-Path $repo 'evals') -Force | Out-Null
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-artifacts.json'

        New-Manifest -Path $manifest -Artifacts @(
            @{ path = '.github/agents/removed.agent.md'; status = 'D' }
        )

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -EvalRoot 'evals' -OutFile $outFile -RepoRoot $repo 3>$null
        $LASTEXITCODE | Should -Be 0
        $data = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
        $data.scope | Should -Be 'artifacts'
        $data.flagged | Should -BeFalse
    }

    It 'Skips manifest artifacts missing on disk and exits 0' {
        $repo = New-Repo
        New-Item -ItemType Directory -Path (Join-Path $repo 'evals') -Force | Out-Null
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-artifacts.json'

        New-Manifest -Path $manifest -Artifacts @(
            @{ path = '.github/agents/ghost.agent.md'; status = 'modified' }
        )

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -EvalRoot 'evals' -OutFile $outFile -RepoRoot $repo 3>$null
        $LASTEXITCODE | Should -Be 0
        $data = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
        $data.scope | Should -Be 'artifacts'
        $data.flagged | Should -BeFalse
    }

    It 'Moderates combined specs and changed artifacts and exits 0 when clean' {
        $repo = New-Repo
        New-EvalSpec -RepoRoot $repo -RelativePath 'evals/skill-quality/example.eval.yaml' | Out-Null
        $artifact = '.github/agents/clean.agent.md'
        New-Item -ItemType Directory -Path (Join-Path $repo '.github/agents') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $repo $artifact) -Value "---`napplyTo: '**'`n---`nHello world." -Encoding utf8 -NoNewline

        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-artifacts.json'
        New-Manifest -Path $manifest -Artifacts @(
            @{ path = $artifact; status = 'modified' }
        )

        $stubDir = New-PythonStub -OutputJson '{"records":[],"summary":{"total":2,"flaggedCount":0}}'
        $env:PATH = "$stubDir$([System.IO.Path]::PathSeparator)$($script:OrigPath)"
        $env:HVE_MODERATION_PYTHON = 'python'

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -EvalRoot 'evals' -OutFile $outFile -RepoRoot $repo 3>$null
        $LASTEXITCODE | Should -Be 0
        Test-Path $outFile | Should -BeTrue
    }

    It 'Propagates exit 1 when moderated content is flagged' {
        $repo = New-Repo
        New-EvalSpec -RepoRoot $repo -RelativePath 'evals/skill-quality/example.eval.yaml' | Out-Null
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-artifacts.json'

        $stubDir = New-PythonStub -OutputJson '{"records":[{"id":"evals/skill-quality/example.eval.yaml","scores":{"toxicity":0.95},"flagged":true,"flaggedLabels":["toxicity"]}],"summary":{"total":1,"flaggedCount":1}}'
        $env:PATH = "$stubDir$([System.IO.Path]::PathSeparator)$($script:OrigPath)"
        $env:HVE_MODERATION_PYTHON = 'python'

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -EvalRoot 'evals' -OutFile $outFile -RepoRoot $repo 2>$null
        $LASTEXITCODE | Should -Be 1
    }
}
