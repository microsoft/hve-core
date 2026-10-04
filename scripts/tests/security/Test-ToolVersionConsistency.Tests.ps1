#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Test-ToolVersionConsistency.ps1')

    $script:Amd = 'a' * 64
    $script:Arm = 'b' * 64
    $script:Wheel = 'c' * 64
    $script:Digest = 'sha256:' + ('d' * 64)

    function script:New-Manifest {
        param([object[]]$ExtraTools = @())
        $tools = @(
            [ordered]@{
                name = 'gitleaks'; repo = 'gitleaks/gitleaks'; version = '8.30.0'; verification = 'published-checksums'; envPrefix = 'GITLEAKS'
                sha256ByArch = @{ linux_amd64 = $script:Amd; linux_arm64 = $script:Arm }
                assetTemplateByArch = @{ linux_amd64 = 'https://x/{version}/amd64'; linux_arm64 = 'https://x/{version}/arm64' }
            }
            [ordered]@{
                name = 'uv'; repo = 'astral-sh/uv'; version = '0.10.9'; verification = 'published-checksums'; envPrefix = 'UV'
                sha256ByArch = @{ linux_amd64 = $script:Amd; linux_arm64 = $script:Arm }
                assetTemplateByArch = @{ linux_amd64 = 'https://x/{version}/amd64'; linux_arm64 = 'https://x/{version}/arm64' }
            }
            [ordered]@{
                name = 'vscode-cli'; repo = 'microsoft/vscode'; version = '1.139.0'; verification = 'published-checksums'; envPrefix = 'VSCODE_CLI'
                registry = 'vscode-update'; commit = '2242ebbb54efeeb0129e08e919e7e8d43033cd83'; sha256ByArch = @{ linux_amd64 = $script:Wheel }
            }
            [ordered]@{ name = 'gh-aw'; repo = 'github/gh-aw'; version = '0.86.2'; verification = 'published-checksums'; envPrefix = 'GH_AW'
                sha256ByArch = @{ linux_amd64 = $script:Amd }; assetTemplateByArch = @{ linux_amd64 = 'https://x/{version}/amd64' }
            }
            [ordered]@{ name = 'gh-aw-firewall'; repo = 'github/gh-aw-firewall'; version = '0.27.44'; verification = 'oci-digest'; images = @{ agent = $script:Digest } }
        ) + $ExtraTools
        return [ordered]@{ tools = $tools }
    }

    function script:New-Repo {
        param([hashtable]$Files = @{}, [object]$Manifest = (New-Manifest))
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $root 'scripts/security') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root '.github/workflows') -Force | Out-Null
        $Manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $root 'scripts/security/tool-checksums.json') -Encoding utf8
        foreach ($relative in $Files.Keys) {
            $path = Join-Path $root $relative
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            Set-Content -LiteralPath $path -Value $Files[$relative] -Encoding utf8
        }
        return $root
    }

    function script:Invoke-Check {
        param([string]$Root, [string]$Sarif)
        return Invoke-ToolVersionConsistency -RepoRoot $Root -SarifPath $Sarif
    }
}

Describe 'Manifest validation' -Tag 'Unit' {
    It 'accepts a well-formed manifest' {
        (Invoke-Check (New-Repo)).Findings | Should -BeNullOrEmpty
    }

    It 'reports <Name>' -ForEach @(
        @{ Name = 'a bad verification'; Tool = [ordered]@{ name = 't'; repo = 'o/r'; version = '1.0.0'; verification = 'trust-me'; sha256ByArch = @{ linux_amd64 = ('e' * 64) } }; Pattern = 'verification' }
        @{ Name = 'a v-prefixed version'; Tool = [ordered]@{ name = 't'; repo = 'o/r'; version = 'v1.0.0'; verification = 'pypi'; package = 'p'; sha256ByArch = @{ linux_amd64 = ('e' * 64) } }; Pattern = 'must not start with v' }
        @{ Name = 'a short digest'; Tool = [ordered]@{ name = 't'; repo = 'o/r'; version = '1.0.0'; verification = 'pypi'; package = 'p'; sha256ByArch = @{ linux_amd64 = 'abc' } }; Pattern = '64 lowercase hex' }
        @{ Name = 'missing attestation details'; Tool = [ordered]@{ name = 't'; repo = 'o/r'; version = '1.0.0'; verification = 'attestation'; sha256ByArch = @{ linux_amd64 = ('e' * 64) }; assetTemplateByArch = @{ linux_amd64 = 'u' } }; Pattern = 'attestation.repo' }
        @{ Name = 'a missing asset template'; Tool = [ordered]@{ name = 't'; repo = 'o/r'; version = '1.0.0'; verification = 'release-digest'; sha256ByArch = @{ linux_amd64 = ('e' * 64) } }; Pattern = 'assetTemplateByArch' }
        @{ Name = 'an image without a digest'; Tool = [ordered]@{ name = 't'; repo = 'o/r'; version = '1.0.0'; verification = 'oci-digest'; images = @{ x = 'latest' } }; Pattern = 'sha256: digest' }
        @{ Name = 'a duplicate envPrefix'; Tool = [ordered]@{ name = 't'; repo = 'o/r'; version = '1.0.0'; verification = 'pypi'; package = 'p'; envPrefix = 'UV'; sha256ByArch = @{ linux_amd64 = ('e' * 64) } }; Pattern = 'duplicate envPrefix' }
    ) {
        $result = Invoke-Check (New-Repo -Manifest (New-Manifest -ExtraTools @($Tool)))
        $result.ExitCode | Should -Be 1
        $result.Findings.RuleId | Should -Contain 'tool-version/manifest-invalid'
        ($result.Findings.Message -join ' ') | Should -Match $Pattern
    }
}

Describe 'File checks' -Tag 'Unit' {
    It 'passes matching versions and checksums in workflows, actions, and devcontainer scripts' {
        $files = @{
            '.github/workflows/scan.yml'          = "env:`n  GITLEAKS_VERSION: '8.30.0'`n  GITLEAKS_SHA256: '$($script:Amd)'"
            '.github/actions/setup/action.yml'    = "env:`n  UV_VERSION: 0.10.9`n  UV_X86_64_SHA256: $($script:Amd)`n  UV_AARCH64_SHA256: $($script:Arm)"
            '.devcontainer/scripts/on-create.sh'  = "GITLEAKS_VERSION=`"8.30.0`"`nGITLEAKS_SHA256=`"$($script:Arm)`""
        }
        $result = Invoke-Check (New-Repo -Files $files)
        $result.Findings | Should -BeNullOrEmpty
        @($result.ScannedFiles).Count | Should -Be 3
    }

    It 'reports a version and checksum that drifted' {
        $files = @{ '.devcontainer/scripts/on-create.sh' = "GITLEAKS_VERSION=`"8.18.2`"`nGITLEAKS_SHA256=`"$('f' * 64)`"" }
        $result = Invoke-Check (New-Repo -Files $files)
        $result.ExitCode | Should -Be 1
        ($result.Findings.RuleId | Sort-Object) -join ',' | Should -Be 'tool-version/checksum-mismatch,tool-version/version-mismatch'
        ($result.Findings | Where-Object RuleId -EQ 'tool-version/version-mismatch').Line | Should -Be 1
        ($result.Findings | Where-Object RuleId -EQ 'tool-version/checksum-mismatch').Line | Should -Be 2
    }

    It 'ignores non-arch checksums that share a prefix' {
        $files = @{ '.github/workflows/demo.yml' = "env:`n  UV_CACHE_SHA256: $('f' * 64)" }
        (Invoke-Check (New-Repo -Files $files)).Findings | Should -BeNullOrEmpty
    }

    It 'reports an unregistered tool pinned with a checksum' {
        $files = @{ '.github/workflows/new.yml' = "env:`n  TRIVY_VERSION: '0.60.0'`n  TRIVY_SHA256: $('f' * 64)" }
        $result = Invoke-Check (New-Repo -Files $files)
        $result.Findings.RuleId | Should -Be 'tool-version/unregistered-tool'
        $result.Findings.Message | Should -Match 'TRIVY'
    }

    It 'does not treat a data version without a checksum as a tool' {
        $files = @{ '.github/workflows/release.yml' = "env:`n  RELEASE_VERSION: 1.2.3" }
        (Invoke-Check (New-Repo -Files $files)).Findings | Should -BeNullOrEmpty
    }

    It 'reports a download URL that does not use the manifest commit' {
        $files = @{ '.github/workflows/demo.yml' = "env:`n  VSCODE_CLI_URL: https://example/stable/0000000000000000000000000000000000000000/cli.tar.gz`n  VSCODE_CLI_SHA256: $($script:Wheel)" }
        (Invoke-Check (New-Repo -Files $files)).Findings.RuleId | Should -Be 'tool-version/commit-mismatch'
    }

    It 'reports any astral-sh/setup-uv step: <Name>' -ForEach @(
        @{ Name = 'matching version'; Uses = 'astral-sh/setup-uv@0123456789abcdef0123456789abcdef01234567 # v10'; With = "        with:`n          version: `"0.10.9`"" }
        @{ Name = 'no with block'; Uses = 'astral-sh/setup-uv@0123456789abcdef0123456789abcdef01234567 # v10'; With = '' }
        @{ Name = 'quoted tag ref'; Uses = "'astral-sh/setup-uv@v7'"; With = '' }
    ) {
        $workflow = "jobs:`n  a:`n    steps:`n      - name: Setup uv`n        uses: $Uses`n$With`n      - name: Next step`n        run: echo hi"
        $result = Invoke-Check (New-Repo -Files @{ '.github/workflows/py.yml' = $workflow })
        @($result.Findings.RuleId) | Should -Be @('tool-version/unpinned-install')
        $result.Findings.Line | Should -Be 5
        $result.Findings.Message | Should -Match '\./\.github/actions/setup-uv'
    }

    It 'accepts the local setup-uv composite and similarly named actions' {
        $workflow = "jobs:`n  a:`n    steps:`n      - uses: ./.github/actions/setup-uv`n      - uses: astral-sh/setup-uv-extra@0123456789abcdef0123456789abcdef01234567`n      - run: echo astral-sh/setup-uv"
        (Invoke-Check (New-Repo -Files @{ '.github/workflows/py.yml' = $workflow })).Findings | Should -BeNullOrEmpty
    }

    It 'checks the gh-aw compiler version and firewall images in lock files' {
        $lock = "# gh-aw-metadata: {`"compiler_version`":`"v0.86.1`"}`nimage: ghcr.io/github/gh-aw-firewall/agent:0.27.44@sha256:$('0' * 64)`nimage2: ghcr.io/github/gh-aw-firewall/agent:0.27.40"
        $result = Invoke-Check (New-Repo -Files @{ '.github/workflows/x.lock.yml' = $lock })
        @($result.Findings).Count | Should -Be 3
        ($result.Findings.Message -join ' ') | Should -Match 'Compiled with gh-aw 0.86.1'
        @($result.Findings | Where-Object RuleId -EQ 'tool-version/image-mismatch').Count | Should -Be 2
    }

    It 'accepts a matching lock file' {
        $lock = "# gh-aw-metadata: {`"compiler_version`":`"v0.86.2`"}`nimage: ghcr.io/github/gh-aw-firewall/agent:0.27.44@$($script:Digest)`nimage2: ghcr.io/github/gh-aw-firewall/agent:0.27.44"
        (Invoke-Check (New-Repo -Files @{ '.github/workflows/x.lock.yml' = $lock })).Findings | Should -BeNullOrEmpty
    }

    It 'does not apply env checks inside lock files' {
        $lock = "env:`n  GITLEAKS_VERSION: 1.0.0"
        (Invoke-Check (New-Repo -Files @{ '.github/workflows/x.lock.yml' = $lock })).Findings | Should -BeNullOrEmpty
    }
}

Describe 'Runtime checks' -Tag 'Unit' {
    BeforeAll {
        $script:Versions = @{ '.node-version' = '24.21.0'; '.python-version' = '3.12.15' }
    }

    It 'accepts version-file inputs, a matching literal, and matching devcontainer features' {
        $workflow = @"
jobs:
  build:
    steps:
      - name: Setup Node.js
        uses: actions/setup-node@0000000000000000000000000000000000000000 # v7.0.0
        with:
          node-version-file: .node-version
      - uses: actions/setup-python@0000000000000000000000000000000000000000 # v7.0.0
        with:
          python-version-file: ./.python-version
  publish:
    steps:
      - uses: actions/setup-node@0000000000000000000000000000000000000000 # v7.0.0
        with:
          node-version: "24.21.0"
"@
        $devcontainer = '{ "features": { "ghcr.io/devcontainers/features/node:1": { "version": "24.21.0" }, "ghcr.io/devcontainers/features/python:1": { "version": "3.12.15", "installTools": false } } }'
        $result = Invoke-Check (New-Repo -Files ($script:Versions + @{ '.github/workflows/ci.yml' = $workflow; '.devcontainer/devcontainer.json' = $devcontainer }))
        $result.Findings | Should -BeNullOrEmpty
        $result.ScannedFiles | Should -Contain '.devcontainer/devcontainer.json'
    }

    It 'reports <Name>' -ForEach @(
        @{ Name = 'a floating literal'; With = "        with:`n          node-version: '24'"; Rule = 'tool-version/runtime-mismatch'; Pattern = 'pins node 24 but' }
        @{ Name = 'another version file'; With = "        with:`n          node-version-file: package.json"; Rule = 'tool-version/runtime-mismatch'; Pattern = 'reads package.json' }
        @{ Name = 'an expression'; With = "        with:`n          node-version: `${{ matrix.node }}"; Rule = 'tool-version/runtime-mismatch'; Pattern = 'matrix.node' }
        @{ Name = 'no version input'; With = "        with:`n          cache: npm"; Rule = 'tool-version/runtime-unpinned'; Pattern = 'sets no version' }
    ) {
        $workflow = "jobs:`n  build:`n    steps:`n      - name: Setup`n        uses: actions/setup-node@0000000000000000000000000000000000000000`n$With"
        $result = Invoke-Check (New-Repo -Files ($script:Versions + @{ '.github/workflows/ci.yml' = $workflow }))
        $result.ExitCode | Should -Be 1
        @($result.Findings).Count | Should -Be 1
        $result.Findings[0].RuleId | Should -Be $Rule
        $result.Findings[0].Message | Should -Match ([regex]::Escape($Pattern))
        $result.Findings[0].Line | Should -Be 5
    }

    It 'does not attribute a later step input to a setup step' {
        $workflow = @"
jobs:
  build:
    steps:
      - uses: actions/setup-python@0000000000000000000000000000000000000000
      - uses: example/other@0000000000000000000000000000000000000000
        with:
          python-version-file: .python-version
"@
        $result = Invoke-Check (New-Repo -Files ($script:Versions + @{ '.github/workflows/ci.yml' = $workflow }))
        @($result.Findings).RuleId | Should -Be @('tool-version/runtime-unpinned')
    }

    It 'checks setup steps in lock files and composite actions' {
        $step = "      - uses: actions/setup-node@0000000000000000000000000000000000000000`n        with:`n          node-version: '24'"
        $files = $script:Versions + @{
            '.github/workflows/x.lock.yml'     = "jobs:`n  agent:`n    steps:`n$step"
            '.github/actions/setup/action.yml' = "runs:`n  using: composite`n  steps:`n$step"
        }
        $result = Invoke-Check (New-Repo -Files $files)
        @($result.Findings | Where-Object RuleId -EQ 'tool-version/runtime-mismatch').Count | Should -Be 2
    }

    It 'reports a malformed version file and treats its setup steps as unpinned' {
        $workflow = "jobs:`n  build:`n    steps:`n      - uses: actions/setup-python@0000000000000000000000000000000000000000`n        with:`n          python-version-file: .python-version"
        $result = Invoke-Check (New-Repo -Files @{ '.node-version' = '24.21.0'; '.python-version' = '3.12'; '.github/workflows/ci.yml' = $workflow })
        $result.Findings.RuleId | Should -Contain 'tool-version/runtime-invalid'
        $result.Findings.RuleId | Should -Contain 'tool-version/runtime-unpinned'
    }

    It 'reports a devcontainer feature that differs from the version file' {
        $devcontainer = "{`n  `"features`": {`n    `"ghcr.io/devcontainers/features/python:1`": { `"version`": `"3.11`" }`n  }`n}"
        $result = Invoke-Check (New-Repo -Files ($script:Versions + @{ '.devcontainer/devcontainer.json' = $devcontainer }))
        @($result.Findings).Count | Should -Be 1
        $result.Findings[0].RuleId | Should -Be 'tool-version/runtime-mismatch'
        $result.Findings[0].Message | Should -Match 'uses 3\.11 but needs 3\.12\.15'
        $result.Findings[0].Line | Should -Be 3
    }
}

Describe 'SARIF output' -Tag 'Unit' {
    It 'writes every rule and each finding to SARIF' {
        $sarif = Join-Path $TestDrive 'out/tool.sarif'
        $files = @{ '.devcontainer/scripts/on-create.sh' = 'GITLEAKS_VERSION="8.18.2"' }
        $null = Invoke-Check -Root (New-Repo -Files $files) -Sarif $sarif
        $doc = Get-Content -Raw $sarif | ConvertFrom-Json
        $doc.runs[0].tool.driver.name | Should -Be 'hve-tool-version-consistency'
        @($doc.runs[0].tool.driver.rules).Count | Should -Be 10
        @($doc.runs[0].results).Count | Should -Be 1
        $doc.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri | Should -Be '.devcontainer/scripts/on-create.sh'
    }
}

Describe 'Repository' -Tag 'Unit' {
    It 'has no tool version drift' {
        $root = Join-Path $PSScriptRoot '../../..'
        $result = Invoke-ToolVersionConsistency -RepoRoot $root
        ($result.Findings | ForEach-Object { "$($_.File):$($_.Line) $($_.Message)" }) | Should -BeNullOrEmpty
    }
}
