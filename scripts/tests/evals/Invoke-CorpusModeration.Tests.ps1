#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-CorpusModeration.ps1'
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

        $shim = Join-Path $stubDir 'python.cmd'
        "@pwsh -NoProfile -File `"$stubScript`" %*" | Set-Content -LiteralPath $shim -Encoding ascii -NoNewline
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
}

Describe 'Invoke-CorpusModeration.ps1' -Tag 'Unit' {
    AfterEach {
        $env:PATH = $script:OrigPath
    }

    It 'Writes empty corpus result and exits 0 when manifest is missing' {
        $repo = Join-Path $TestDrive ("repo-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        $outFile = Join-Path $repo 'logs/moderation-corpus.json'
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -OutFile $outFile -RepoRoot $repo 3>$null
        $LASTEXITCODE | Should -Be 0
        Test-Path $outFile | Should -BeTrue
        $data = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
        $data.scope | Should -Be 'corpus'
        $data.summary.total | Should -Be 0
        $data.summary.flaggedCount | Should -Be 0
    }

    It 'Writes empty corpus result and exits 0 when manifest has no corpus paths' {
        $repo = Join-Path $TestDrive ("repo-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-corpus.json'

        New-Manifest -Path $manifest -Artifacts @(
            @{ path = 'docs/readme.md'; status = 'modified' },
            @{ path = '.github/workflows/ci.yml'; status = 'modified' }
        )

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -OutFile $outFile -RepoRoot $repo
        $LASTEXITCODE | Should -Be 0
        Test-Path $outFile | Should -BeTrue
        $data = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
        $data.scope | Should -Be 'corpus'
        $data.summary.total | Should -Be 0
    }

    It 'Exits 0 when all listed corpus files are missing on disk' {
        $repo = Join-Path $TestDrive ("repo-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repo -Force | Out-Null
        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-corpus.json'

        New-Manifest -Path $manifest -Artifacts @(
            @{ path = '.github/agents/ghost.agent.md'; status = 'modified' }
        )

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -OutFile $outFile -RepoRoot $repo 3>$null
        $LASTEXITCODE | Should -Be 0
    }

    It 'Propagates exit 0 for a clean corpus file' {
        $repo = Join-Path $TestDrive ("repo-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $repo '.github/agents') -Force | Out-Null
        $artifact = '.github/agents/clean.agent.md'
        Set-Content -LiteralPath (Join-Path $repo $artifact) -Value "---`napplyTo: '**'`n---`nHello world." -Encoding utf8 -NoNewline

        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-corpus.json'
        New-Manifest -Path $manifest -Artifacts @(
            @{ path = $artifact; status = 'modified' }
        )

        $stubDir = New-PythonStub -OutputJson '{"records":[{"id":".github/agents/clean.agent.md","scores":{"toxicity":0.05},"flagged":false,"flaggedLabels":[]}],"summary":{"total":1,"flaggedCount":0}}'
        $env:PATH = "$stubDir;$($script:OrigPath)"

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -OutFile $outFile -RepoRoot $repo 2>$null
        $LASTEXITCODE | Should -Be 0
        Test-Path $outFile | Should -BeTrue
    }

    It 'Propagates non-zero exit when a corpus file is flagged' {
        $repo = Join-Path $TestDrive ("repo-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $repo '.github/prompts') -Force | Out-Null
        $artifact = '.github/prompts/bad.prompt.md'
        Set-Content -LiteralPath (Join-Path $repo $artifact) -Value 'this content should trip the stub' -Encoding utf8 -NoNewline

        $manifest = Join-Path $repo 'logs/changed-ai-artifacts.json'
        $outFile = Join-Path $repo 'logs/moderation-corpus.json'
        New-Manifest -Path $manifest -Artifacts @(
            @{ path = $artifact; status = 'modified' }
        )

        $stubDir = New-PythonStub -OutputJson '{"records":[{"id":".github/prompts/bad.prompt.md","scores":{"toxicity":0.92},"flagged":true,"flaggedLabels":["toxicity"]}],"summary":{"total":1,"flaggedCount":1}}'
        $env:PATH = "$stubDir;$($script:OrigPath)"

        & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $manifest -OutFile $outFile -RepoRoot $repo 2>$null
        $LASTEXITCODE | Should -Be 1
    }
}
