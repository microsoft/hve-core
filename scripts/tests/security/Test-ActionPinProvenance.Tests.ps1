#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Test-ActionPinProvenance.ps1')

    $script:Release = 'a' * 40
    $script:Other = 'b' * 40
    $script:Untagged = 'c' * 40
    $script:TagObject = 'd' * 40
    $script:BundleOnly = 'e' * 40

    function script:New-PinRepo {
        param([hashtable]$Files)
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        foreach ($relative in $Files.Keys) {
            $path = Join-Path $root $relative
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            Set-Content -LiteralPath $path -Value $Files[$relative]
        }
        return $root
    }

    function script:Set-Upstream {
        param([string[]]$TagLines, [string]$Branch = 'main')
        $script:TagLines = $TagLines
        $script:HeadLines = @("ref: refs/heads/$Branch`tHEAD", "$($script:Other)`tHEAD")
        Mock Invoke-GitLsRemote {
            if ($Arguments[0] -eq '--tags') { return $script:TagLines }
            return $script:HeadLines
        }
    }
}

Describe 'Test-ActionPinProvenance' -Tag 'Unit' {
    BeforeEach {
        $script:UpstreamCache = @{}
        $script:ReachabilityCache = @{}
        Set-Upstream -TagLines @(
            "$($script:Release)`trefs/tags/v4.38.2"
            "$($script:Release)`trefs/tags/v4"
            "$($script:Other)`trefs/tags/v3.27.0"
            "$($script:BundleOnly)`trefs/tags/codeql-bundle-v2.23.6"
            "$($script:TagObject)`trefs/tags/v9"
            "$($script:Release)`trefs/tags/v9^{}"
        )
        Mock Invoke-CompareRequest { [pscustomobject]@{ Status = 200; Body = [pscustomobject]@{ status = 'behind' } } }
    }

    Describe 'Get-ActionPinReference' -Tag 'Unit' {
        It 'reads uses: pins with comments and remediation table rows with keys' {
            $root = New-PinRepo @{
                '.github/workflows/a.yml'   = @(
                    'steps:'
                    "  - uses: org/act/sub@$($script:Release) # v4.38.2 extra words"
                    "    uses: org/act@$($script:Other)"
                    '  - uses: ./.github/actions/local'
                    '  - uses: org/act@v4'
                )
                'scripts/security/Map.ps1' = @(
                    "    `"org/act@v4`" = `"org/act@$($script:Release)`" # v4.38.2"
                    '    "not a row"'
                )
            }
            $refs = @(Get-ActionPinReference -RepoRoot $root -Paths @('.github/workflows', 'scripts/security/Map.ps1'))
            $refs | Should -HaveCount 3
            $refs[0].Repo | Should -Be 'org/act'
            $refs[0].Label | Should -Be 'v4.38.2'
            $refs[0].Line | Should -Be 2
            $refs[1].Label | Should -Be ''
            $refs[2].Key | Should -Be 'org/act@v4'
            $refs[2].File | Should -Be 'scripts/security/Map.ps1'
        }
    }

    Describe 'Get-PinFinding' -Tag 'Unit' {
        BeforeAll {
            function script:New-Ref {
                param([string]$Sha, [string]$Label, [string]$Key = '')
                [pscustomobject]@{ File = 'w.yml'; Line = 7; Repo = 'org/act'; Sha = $Sha; Comment = $Label; Label = $Label; Key = $Key }
            }
        }

        It 'accepts a release tag that points at the pinned commit' {
            @(Get-PinFinding -References @(New-Ref $script:Release 'v4.38.2')) | Should -HaveCount 0
        }

        It 'reports <Name>' -ForEach @(
            @{ Name = 'a tag that points elsewhere'; Sha = 'Other'; Label = 'v4.38.2'; Rule = 'action-pin/comment-mismatch'; Pattern = 'points at aaaaaaaaaaaa' }
            @{ Name = 'a version that is not a tag'; Sha = 'Release'; Label = 'v4.99.0'; Rule = 'action-pin/comment-mismatch'; Pattern = 'not a tag at this commit' }
            @{ Name = 'a moving major tag'; Sha = 'Release'; Label = 'v4'; Rule = 'action-pin/comment-mismatch'; Pattern = 'moving tag' }
            @{ Name = 'a missing comment'; Sha = 'Release'; Label = ''; Rule = 'action-pin/comment-missing'; Pattern = 'v4.38.2' }
            @{ Name = 'free text on a tagged commit'; Sha = 'Release'; Label = 'PR'; Rule = 'action-pin/comment-mismatch'; Pattern = 'v4.38.2' }
            @{ Name = 'a mislabeled bundle commit'; Sha = 'BundleOnly'; Label = 'v3.27.0'; Rule = 'action-pin/comment-mismatch'; Pattern = 'codeql-bundle-v2.23.6' }
        ) {
            $findings = @(Get-PinFinding -References @(New-Ref (Get-Variable -Name $Sha -Scope Script -ValueOnly) $Label))
            $findings | Should -HaveCount 1
            $findings[0].RuleId | Should -Be $Rule
            $findings[0].Message | Should -Match ([regex]::Escape($Pattern))
            $findings[0].Line | Should -Be 7
        }

        It 'reports a pin of an annotated tag object and names its commit' {
            $findings = @(Get-PinFinding -References @(New-Ref $script:TagObject 'v9'))
            $findings | Should -HaveCount 1
            $findings[0].RuleId | Should -Be 'action-pin/tag-object'
            $findings[0].Message | Should -Match "Pin commit $($script:Release) labeled v4.38.2"
        }

        It 'accepts free text on an untagged commit in the default branch history' {
            @(Get-PinFinding -References @(New-Ref $script:Untagged 'PR #2823 squash')) | Should -HaveCount 0
            Should -Invoke Invoke-CompareRequest -Times 1 -ParameterFilter { $Uri -like "*/repos/org/act/compare/main...$($script:Untagged)" }
        }

        It 'reports an untagged commit outside the default branch as unreachable' {
            Mock Invoke-CompareRequest { [pscustomobject]@{ Status = 200; Body = [pscustomobject]@{ status = 'diverged' } } }
            $findings = @(Get-PinFinding -References @(New-Ref $script:Untagged 'PR'))
            $findings[0].RuleId | Should -Be 'action-pin/unreachable-commit'
        }

        It 'reports a commit the repository does not contain as unreachable' {
            Mock Invoke-CompareRequest { [pscustomobject]@{ Status = 404; Body = $null } }
            (@(Get-PinFinding -References @(New-Ref $script:Untagged 'v1.0.0')))[0].RuleId | Should -Be 'action-pin/unreachable-commit'
        }

        It 'fails closed when <Name>' -ForEach @(
            @{ Name = 'the compare API errors'; Tags = $true }
            @{ Name = 'tags cannot be read'; Tags = $false }
        ) {
            Mock Invoke-CompareRequest { [pscustomobject]@{ Status = 502; Body = $null } }
            if (-not $Tags) { Mock Invoke-GitLsRemote { $null } }
            $findings = @(Get-PinFinding -References @(New-Ref $script:Untagged 'PR'))
            $findings | Should -HaveCount 1
            $findings[0].RuleId | Should -Be 'action-pin/upstream-unavailable'
        }

        It 'reports a remediation entry whose release is outside its key line' {
            @(Get-PinFinding -References @(New-Ref $script:Release 'v4.38.2' 'org/act@v4')) | Should -HaveCount 0
            $findings = @(Get-PinFinding -References @(New-Ref $script:Release 'v4.38.2' 'org/act@v3'))
            $findings | Should -HaveCount 1
            $findings[0].Message | Should -Match 'outside the v3 line'
        }

        It 'reads each upstream repository once per run' {
            $refs = @((New-Ref $script:Release 'v4.38.2'), (New-Ref $script:Other 'v3.27.0'))
            $null = Get-PinFinding -References $refs
            Should -Invoke Invoke-GitLsRemote -Times 2 -Exactly
        }
    }

    Describe 'Invoke-ActionPinProvenance' -Tag 'Unit' {
        It 'writes every rule and each finding to SARIF and sets the exit code' {
            $root = New-PinRepo @{ '.github/workflows/w.yml' = @('steps:', "  - uses: org/act@$($script:Other) # v4.38.2") }
            $sarif = Join-Path $TestDrive 'out/pins.sarif'
            $result = Invoke-ActionPinProvenance -RepoRoot $root -Paths @('.github/workflows') -SarifPath $sarif
            $result.ExitCode | Should -Be 1
            $doc = Get-Content -Raw $sarif | ConvertFrom-Json
            $doc.runs[0].tool.driver.name | Should -Be 'hve-action-pin-provenance'
            @($doc.runs[0].tool.driver.rules).Count | Should -Be 5
            $doc.runs[0].results[0].ruleId | Should -Be 'action-pin/comment-mismatch'
            $doc.runs[0].results[0].locations[0].physicalLocation.artifactLocation.uri | Should -Be '.github/workflows/w.yml'
        }

        It 'returns exit code 0 when every pin verifies' {
            $root = New-PinRepo @{ '.github/workflows/w.yml' = @('steps:', "  - uses: org/act@$($script:Release) # v4.38.2") }
            (Invoke-ActionPinProvenance -RepoRoot $root -Paths @('.github/workflows')).ExitCode | Should -Be 0
        }
    }
}
