#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Install-HveCorePlugin.ps1')
    Mock Write-Host {}

    $script:DefaultSha = '0c14eea959a5ff355871205acf14807c7fa7d4a7'

    function New-TestPluginSource {
        <#
        .SYNOPSIS
            Creates a valid minimal HVE Core plugin source fixture.
        .PARAMETER Path
            Fixture source path.
        .OUTPUTS
            [string] Created source path.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        New-Item -ItemType Directory -Path (Join-Path $Path '.github/plugin') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $Path 'README.md') -Value '# Fixture' -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $Path 'LICENSE') -Value 'MIT' -Encoding UTF8

        $Manifest = [ordered]@{
            name        = 'hve-core'
            description = 'Fixture plugin'
            version     = '3.2.2'
            author      = [ordered]@{ name = 'Microsoft'; url = 'https://www.microsoft.com' }
            homepage    = 'https://github.com/microsoft/hve-core'
            repository  = 'https://github.com/microsoft/hve-core'
            license     = 'MIT'
            keywords    = @('hve', 'plugins')
            agents      = @()
            commands    = @()
            rules       = @()
            skills      = @()
        }
        Set-Content -LiteralPath (Join-Path $Path 'plugin.json') `
            -Value (ConvertTo-DeterministicJson -InputObject $Manifest) -Encoding UTF8 -NoNewline

        $Catalog = [ordered]@{
            name     = 'hve-core'
            metadata = [ordered]@{ description = 'HVE Core'; version = '3.2.2' }
            owner    = [ordered]@{ name = 'Microsoft' }
            plugins  = @(
                [ordered]@{
                    name        = 'hve-core'
                    source      = '.'
                    description = 'Fixture plugin'
                    version     = '3.2.2'
                    author      = [ordered]@{ name = 'Microsoft'; url = 'https://www.microsoft.com' }
                    homepage    = 'https://github.com/microsoft/hve-core'
                    repository  = 'https://github.com/microsoft/hve-core'
                    license     = 'MIT'
                    keywords    = @('hve', 'plugins')
                }
            )
        }
        Set-Content -LiteralPath (Join-Path $Path '.github/plugin/marketplace.json') `
            -Value (ConvertTo-DeterministicJson -InputObject $Catalog) -Encoding UTF8 -NoNewline
        return $Path
    }

    function New-TestPinRoot {
        <#
        .SYNOPSIS
            Creates a valid filesystem fixture for an existing pin.
        .PARAMETER Path
            Pin root path.
        .PARAMETER CommitSha
            Expected normalized commit SHA.
        .OUTPUTS
            [string] Created pin root.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$CommitSha
        )

        $SourceRoot = New-TestPluginSource -Path (Join-Path $Path 'source')
        $Content = New-PinnedMarketplaceContent -SourceRoot $SourceRoot -CommitSha $CommitSha
        Set-Content -LiteralPath (Join-Path $Path 'marketplace.json') `
            -Value $Content -Encoding UTF8 -NoNewline
        return $Path
    }

}

Describe 'ConvertTo-NormalizedCommitSha' -Tag 'Unit' {
    It 'Normalizes a full uppercase SHA' {
        ConvertTo-NormalizedCommitSha -Value $script:DefaultSha.ToUpperInvariant() |
            Should -BeExactly $script:DefaultSha
    }

    It 'Rejects invalid or abbreviated value <Value>' -ForEach @(
        @{ Value = '0c14eea' }
        @{ Value = ('g' * 40) }
        @{ Value = ('0' * 41) }
    ) {
        { ConvertTo-NormalizedCommitSha -Value $Value } |
            Should -Throw '*full 40-character hexadecimal*'
    }
}

Describe 'Resolve-LocalInstallRoot' -Tag 'Unit' {
    It 'Resolves an absolute filesystem path independently of the working directory' {
        $Expected = [System.IO.Path]::GetFullPath((Join-Path $TestDrive 'pins'))
        Resolve-LocalInstallRoot -Path $Expected | Should -BeExactly $Expected
    }

    It 'Rejects a relative path' {
        { Resolve-LocalInstallRoot -Path 'relative/pins' } |
            Should -Throw '*absolute local filesystem path*'
    }
}

Describe 'Resolve-CanonicalPath' -Tag 'Unit' {
    It 'Rejects a filesystem link that cannot be resolved' {
        Mock Get-Item {
            $Item = [pscustomobject]@{ LinkType = 'SymbolicLink' }
            $Item | Add-Member -MemberType ScriptMethod -Name ResolveLinkTarget -Value { $null }
            return $Item
        }

        { Resolve-CanonicalPath -Path (Join-Path $TestDrive 'broken-link') } |
            Should -Throw '*Filesystem link cannot be resolved*'
    }
}

Describe 'Get-RequiredApplication' -Tag 'Unit' {
    It 'Returns the discovered external application path' {
        Mock Get-Command { [pscustomobject]@{ Path = '/tools/git' } } `
            -ParameterFilter { $Name -eq 'git' -and $CommandType -eq 'Application' }

        Get-RequiredApplication -Name 'git' | Should -BeExactly '/tools/git'
    }

    It 'Rejects a missing application' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'copilot' }

        { Get-RequiredApplication -Name 'copilot' } |
            Should -Throw "*Required application 'copilot'*"
    }
}

Describe 'New-PinnedMarketplaceContent' -Tag 'Unit' {
    BeforeEach {
        $script:SourceRoot = New-TestPluginSource -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
    }

    It 'Builds a deterministic SHA-specific marketplace with a contained source' {
        $Content = New-PinnedMarketplaceContent `
            -SourceRoot $script:SourceRoot `
            -CommitSha $script:DefaultSha
        $Catalog = $Content | ConvertFrom-Json -AsHashtable

        $Catalog['name'] | Should -BeExactly "hve-core-$script:DefaultSha"
        @($Catalog['plugins']) | Should -HaveCount 1
        @($Catalog['plugins'])[0]['name'] | Should -BeExactly 'hve-core'
        @($Catalog['plugins'])[0]['source'] | Should -BeExactly './source'
        $Content | Should -Not -Match "`r"
        $Content.EndsWith("}`n") | Should -BeTrue
    }

    It 'Rejects a canonical source other than dot' {
        $Path = Join-Path $script:SourceRoot '.github/plugin/marketplace.json'
        $Catalog = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
        @($Catalog['plugins'])[0]['source'] = '.github'
        Set-Content -LiteralPath $Path -Value (ConvertTo-DeterministicJson $Catalog) -Encoding UTF8 -NoNewline

        { New-PinnedMarketplaceContent -SourceRoot $script:SourceRoot -CommitSha $script:DefaultSha } |
            Should -Throw "*canonical source '.'*"
    }

    It 'Rejects mismatched metadata field <Field>' -ForEach @(
        @{ Field = 'version'; Value = '9.9.9' }
        @{ Field = 'description'; Value = 'Different' }
        @{ Field = 'license'; Value = 'Apache-2.0' }
    ) {
        $Path = Join-Path $script:SourceRoot '.github/plugin/marketplace.json'
        $Catalog = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
        @($Catalog['plugins'])[0][$Field] = $Value
        Set-Content -LiteralPath $Path -Value (ConvertTo-DeterministicJson $Catalog) -Encoding UTF8 -NoNewline

        { New-PinnedMarketplaceContent -SourceRoot $script:SourceRoot -CommitSha $script:DefaultSha } |
            Should -Throw
    }

    It 'Rejects a missing required root file' {
        Remove-Item -LiteralPath (Join-Path $script:SourceRoot 'LICENSE') -Force

        { New-PinnedMarketplaceContent -SourceRoot $script:SourceRoot -CommitSha $script:DefaultSha } |
            Should -Throw '*Required plugin file*'
    }
}

Describe 'Test-PinnedCheckout' -Tag 'Unit' {
    BeforeEach {
        $script:PinRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $script:PinRoot 'source') -Force | Out-Null
        Mock Invoke-CheckedApplication {
            $Joined = $ArgumentList -join ' '
            switch -Regex ($Joined) {
                'rev-parse --is-inside-work-tree$' { return 'true' }
                'rev-parse --is-bare-repository$' { return 'false' }
                'remote get-url origin$' { return 'https://github.com/microsoft/hve-core.git' }
                'cat-file -t ' { return 'commit' }
                'rev-parse HEAD$' { return $script:DefaultSha }
                'branch --show-current$' { return '' }
                'status --porcelain=v1 --untracked-files=all$' { return '' }
                'ls-files -s$' { return '100644 abc 0 plugin.json' }
                default { throw "Unexpected Git invocation: $Joined" }
            }
        }
    }

    It 'Accepts the exact detached clean commit' {
        Test-PinnedCheckout -GitPath '/tools/git' -PinRoot $script:PinRoot -CommitSha $script:DefaultSha |
            Should -BeTrue
    }

    It 'Rejects a mismatched HEAD' {
        Mock Invoke-CheckedApplication {
            if (($ArgumentList -join ' ') -match 'rev-parse HEAD$') {
                return ('f' * 40)
            }
            return ''
        } -ParameterFilter { ($ArgumentList -join ' ') -match 'rev-parse HEAD$' }

        { Test-PinnedCheckout -GitPath '/tools/git' -PinRoot $script:PinRoot -CommitSha $script:DefaultSha } |
            Should -Throw '*HEAD does not match*'
    }

    It 'Rejects tracked symbolic links' {
        Mock Invoke-CheckedApplication { '120000 abc 0 linked-file' } `
            -ParameterFilter { ($ArgumentList -join ' ') -match 'ls-files -s$' }

        { Test-PinnedCheckout -GitPath '/tools/git' -PinRoot $script:PinRoot -CommitSha $script:DefaultSha } |
            Should -Throw '*symbolic links*'
    }
}

Describe 'Test-PinnedMarketplaceRoot' -Tag 'Unit' {
    BeforeEach {
        $script:PinRoot = New-TestPinRoot `
            -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))) `
            -CommitSha $script:DefaultSha
        Mock Test-PinnedCheckout { $true }
    }

    It 'Accepts exact deterministic wrapper content' {
        Test-PinnedMarketplaceRoot -GitPath '/tools/git' -PinRoot $script:PinRoot -CommitSha $script:DefaultSha |
            Should -BeTrue
    }

    It 'Rejects modified wrapper content without overwriting it' {
        $Path = Join-Path $script:PinRoot 'marketplace.json'
        Set-Content -LiteralPath $Path -Value '{"name":"different"}' -Encoding UTF8 -NoNewline

        { Test-PinnedMarketplaceRoot -GitPath '/tools/git' -PinRoot $script:PinRoot -CommitSha $script:DefaultSha } |
            Should -Throw '*does not match*'
        (Get-Content -LiteralPath $Path -Raw) | Should -BeExactly '{"name":"different"}'
    }
}

Describe 'New-PinnedCheckout' -Tag 'Unit' {
    BeforeEach {
        $script:InstallRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:GitCalls = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-CheckedApplication {
            $Joined = $ArgumentList -join ' '
            $script:GitCalls.Add($Joined)
            if ($Operation -eq 'Detached checkout') {
                New-TestPluginSource -Path $ArgumentList[1] | Out-Null
            }
            switch -Regex ($Joined) {
                'rev-parse FETCH_HEAD$' { return $script:DefaultSha }
                'rev-parse --is-inside-work-tree$' { return 'true' }
                'rev-parse --is-bare-repository$' { return 'false' }
                'remote get-url origin$' { return 'https://github.com/microsoft/hve-core.git' }
                'cat-file -t ' { return 'commit' }
                'rev-parse HEAD$' { return $script:DefaultSha }
                'branch --show-current$' { return '' }
                'status --porcelain=v1 --untracked-files=all$' { return '' }
                'ls-files -s$' { return '100644 abc 0 plugin.json' }
                default { return '' }
            }
        }
    }

    It 'Fetches the full SHA without clone or branch arguments and promotes the pin' {
        $Result = New-PinnedCheckout `
            -GitPath '/tools/git' `
            -InstallRoot $script:InstallRoot `
            -CommitSha $script:DefaultSha

        $Result | Should -BeExactly (Join-Path $script:InstallRoot $script:DefaultSha)
        Test-Path -LiteralPath (Join-Path $Result 'marketplace.json') | Should -BeTrue
        ($script:GitCalls -join "`n") | Should -Match "fetch --depth 1 origin $script:DefaultSha"
        ($script:GitCalls -join "`n") | Should -Match '-c core\.longpaths=true checkout --detach FETCH_HEAD'
        ($script:GitCalls -join "`n") | Should -Match '-c core\.longpaths=true status --porcelain=v1 --untracked-files=all'
        ($script:GitCalls -join "`n") | Should -Not -Match '(^| )clone( |$)'
        ($script:GitCalls -join "`n") | Should -Not -Match '--branch'
    }

    It 'Cleans staging and publishes no final pin after a fetch failure' {
        Mock Invoke-CheckedApplication { throw 'fetch failed' } `
            -ParameterFilter { $Operation -eq 'Exact commit fetch' }

        { New-PinnedCheckout -GitPath '/tools/git' -InstallRoot $script:InstallRoot -CommitSha $script:DefaultSha } |
            Should -Throw '*fetch failed*'
        Test-Path -LiteralPath (Join-Path $script:InstallRoot $script:DefaultSha) | Should -BeFalse
        @(Get-ChildItem -LiteralPath $script:InstallRoot -Filter '.staging-*' -ErrorAction SilentlyContinue) |
            Should -HaveCount 0
    }

    It 'Removes the promoted pin when final validation fails' {
        Mock Test-PinnedMarketplaceRoot {
            if ((Split-Path -Leaf $PinRoot) -notlike '.staging-*') {
                throw 'post-promotion validation failed'
            }
            return $true
        }

        { New-PinnedCheckout -GitPath '/tools/git' -InstallRoot $script:InstallRoot -CommitSha $script:DefaultSha } |
            Should -Throw '*post-promotion validation failed*'
        Test-Path -LiteralPath (Join-Path $script:InstallRoot $script:DefaultSha) | Should -BeFalse
        @(Get-ChildItem -LiteralPath $script:InstallRoot -Filter '.staging-*' -ErrorAction SilentlyContinue) |
            Should -HaveCount 0
    }
}

Describe 'Invoke-HveCorePluginInstall' -Tag 'Unit' {
    BeforeEach {
        $script:InstallRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:PinRoot = Join-Path $script:InstallRoot $script:DefaultSha
        New-Item -ItemType Directory -Path $script:PinRoot -Force | Out-Null
        $script:ApplicationCalls = [System.Collections.Generic.List[string]]::new()

        Mock Get-RequiredApplication {
            if ($Name -eq 'git') { return '/tools/git' }
            return '/tools/copilot'
        }
        Mock Test-PinnedMarketplaceRoot { $true }
        Mock Invoke-ExternalApplication {
            $script:ApplicationCalls.Add("$FilePath $($ArgumentList -join ' ')")
            return [ordered]@{ ExitCode = 0; Output = @() }
        }
    }

    It 'Registers the local marketplace before installing the qualified plugin' {
        $Result = Invoke-HveCorePluginInstall -CommitSha $script:DefaultSha -InstallRoot $script:InstallRoot

        $Result.Status | Should -BeExactly 'Installed'
        $script:ApplicationCalls | Should -HaveCount 2
        $script:ApplicationCalls[0] | Should -BeExactly "/tools/copilot plugin marketplace add $script:PinRoot"
        $script:ApplicationCalls[1] | Should -BeExactly "/tools/copilot plugin install hve-core@hve-core-$script:DefaultSha"
        ($script:ApplicationCalls -join "`n") | Should -Not -Match 'microsoft/hve-core#'
    }

    It 'Stops before install when marketplace registration fails' {
        Mock Invoke-ExternalApplication {
            $script:ApplicationCalls.Add("$FilePath $($ArgumentList -join ' ')")
            return [ordered]@{ ExitCode = 5; Output = @() }
        } -ParameterFilter { $ArgumentList[1] -eq 'marketplace' }

        { Invoke-HveCorePluginInstall -CommitSha $script:DefaultSha -InstallRoot $script:InstallRoot } |
            Should -Throw '*marketplace registration failed*'
        $script:ApplicationCalls | Should -HaveCount 1
        ($script:ApplicationCalls -join "`n") | Should -Not -Match 'plugin install'
    }

    It 'Reports the qualified recovery command when installation fails' {
        Mock Invoke-ExternalApplication {
            $script:ApplicationCalls.Add("$FilePath $($ArgumentList -join ' ')")
            return [ordered]@{ ExitCode = 7; Output = @() }
        } -ParameterFilter { $ArgumentList[1] -eq 'install' }

        { Invoke-HveCorePluginInstall -CommitSha $script:DefaultSha -InstallRoot $script:InstallRoot } |
            Should -Throw "*copilot plugin install hve-core@hve-core-$script:DefaultSha*"
        $script:ApplicationCalls | Should -HaveCount 2
    }

    It 'Performs no external mutation when WhatIf plans a missing pin' {
        Remove-Item -LiteralPath $script:PinRoot -Recurse -Force

        $Result = Invoke-HveCorePluginInstall `
            -CommitSha $script:DefaultSha `
            -InstallRoot $script:InstallRoot `
            -WhatIf

        $Result.Status | Should -BeExactly 'Planned'
        $Result.VerificationPending | Should -BeTrue
        $Result.WhatIf | Should -BeTrue
        $Result.PlannedActions | Should -Be @(
            "Acquire and verify HVE Core commit $script:DefaultSha in a staging directory"
            "Publish the verified pin at $script:PinRoot"
            "Register local marketplace hve-core-$script:DefaultSha at $script:PinRoot"
            "Install qualified plugin hve-core@hve-core-$script:DefaultSha"
        )
        $script:ApplicationCalls | Should -HaveCount 0
        Test-Path -LiteralPath $script:PinRoot | Should -BeFalse
    }

    It 'Rejects an abbreviated SHA before discovering applications or mutating state' {
        { Invoke-HveCorePluginInstall -CommitSha '0c14eea' -InstallRoot $script:InstallRoot } |
            Should -Throw '*full 40-character*'
        Should -Invoke Get-RequiredApplication -Times 0 -Exactly
        Should -Invoke Invoke-ExternalApplication -Times 0 -Exactly
    }
}
