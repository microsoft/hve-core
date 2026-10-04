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

    It 'checks setup-uv version inputs: <Name>' -ForEach @(
        @{ Name = 'matching'; With = "        with:`n          version: `"0.10.9`"`n          enable-cache: auto"; Expected = @() }
        @{ Name = 'different'; With = "        with:`n          version: `"0.10.8`""; Expected = @('tool-version/version-mismatch') }
        @{ Name = 'missing'; With = "        with:`n          enable-cache: false"; Expected = @('tool-version/unpinned-install') }
        @{ Name = 'no with block'; With = ''; Expected = @('tool-version/unpinned-install') }
    ) {
        $workflow = "jobs:`n  a:`n    steps:`n      - name: Setup uv`n        uses: astral-sh/setup-uv@0123456789abcdef0123456789abcdef01234567 # v10`n$With`n      - name: Next step`n        run: echo hi`n          version: 9.9.9"
        $result = Invoke-Check (New-Repo -Files @{ '.github/workflows/py.yml' = $workflow })
        @($result.Findings.RuleId) | Should -Be $Expected
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

Describe 'SARIF output' -Tag 'Unit' {
    It 'writes every rule and each finding to SARIF' {
        $sarif = Join-Path $TestDrive 'out/tool.sarif'
        $files = @{ '.devcontainer/scripts/on-create.sh' = 'GITLEAKS_VERSION="8.18.2"' }
        $null = Invoke-Check -Root (New-Repo -Files $files) -Sarif $sarif
        $doc = Get-Content -Raw $sarif | ConvertFrom-Json
        $doc.runs[0].tool.driver.name | Should -Be 'hve-tool-version-consistency'
        @($doc.runs[0].tool.driver.rules).Count | Should -Be 7
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
