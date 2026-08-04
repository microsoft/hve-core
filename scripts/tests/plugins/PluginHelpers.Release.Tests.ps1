#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../plugins/Modules/PluginHelpers.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force
    Mock Write-Host {} -ModuleName PluginHelpers
}

Describe 'New-PluginReleaseLocator' -Tag 'Unit' {
    Context 'when a release version is supplied' {
        BeforeAll {
            $script:versionLocator = New-PluginReleaseLocator -Version '1.2.3'
        }

        It 'Derives the immutable tag' {
            $script:versionLocator.Ref | Should -BeExactly 'plugins-v1.2.3'
        }

        It 'Defaults the source repository and package path prefix' {
            $script:versionLocator.Repo | Should -BeExactly 'microsoft/hve-core'
            $script:versionLocator.PathPrefix | Should -BeExactly 'plugins'
        }

        It 'Returns only locator keys' {
            @($script:versionLocator.Keys | Sort-Object) | Should -Be @('PathPrefix', 'Ref', 'Repo')
        }
    }

    Context 'when an explicit tag or override is supplied' {
        It 'Accepts the prerelease version <Version>' -ForEach @(
            @{ Version = '1.2.3-beta.1'; ExpectedRef = 'plugins-v1.2.3-beta.1' }
            @{ Version = '10.0.0'; ExpectedRef = 'plugins-v10.0.0' }
        ) {
            (New-PluginReleaseLocator -Version $Version).Ref | Should -BeExactly $ExpectedRef
        }

        It 'Accepts an explicit immutable tag' {
            (New-PluginReleaseLocator -Tag 'plugins-v4.5.6').Ref | Should -BeExactly 'plugins-v4.5.6'
        }

        It 'Accepts an alternate repository and normalizes the path prefix' {
            $locator = New-PluginReleaseLocator -Tag 'plugins-v1.0.0' -Repo 'contoso/contoso-hve' -PathPrefix '/packages/'
            $locator.Repo | Should -BeExactly 'contoso/contoso-hve'
            $locator.PathPrefix | Should -BeExactly 'packages'
        }
    }

    Context 'when the locator is not immutable or is malformed' {
        It 'Rejects <Label>' -ForEach @(
            @{ Label = 'a commit sha'; Parameters = @{ Tag = '0123456789abcdef0123456789abcdef01234567' }; Pattern = 'is a commit sha' }
            @{ Label = 'the default branch'; Parameters = @{ Tag = 'main' }; Pattern = "must use the immutable 'plugins-v<version>' tag form" }
            @{ Label = 'the moving release branch'; Parameters = @{ Tag = 'release/plugins' }; Pattern = "must use the immutable 'plugins-v<version>' tag form" }
            @{ Label = 'an unversioned tag'; Parameters = @{ Tag = 'plugins-v1.2' }; Pattern = "must use the immutable 'plugins-v<version>' tag form" }
            @{ Label = 'an empty tag'; Parameters = @{ Tag = '' }; Pattern = "must use the immutable 'plugins-v<version>' tag form" }
            @{ Label = 'a non-semantic version'; Parameters = @{ Version = '1.2' }; Pattern = 'is not a semantic version' }
            @{ Label = 'a repository without an owner'; Parameters = @{ Tag = 'plugins-v1.2.3'; Repo = 'contoso-hve' }; Pattern = "must use 'owner/name' form" }
            @{ Label = 'a repository with extra segments'; Parameters = @{ Tag = 'plugins-v1.2.3'; Repo = 'contoso/hve/extra' }; Pattern = "must use 'owner/name' form" }
            @{ Label = 'an escaping path prefix'; Parameters = @{ Tag = 'plugins-v1.2.3'; PathPrefix = '../outside' }; Pattern = 'must be a relative forward-slash path' }
            @{ Label = 'a backslash path prefix'; Parameters = @{ Tag = 'plugins-v1.2.3'; PathPrefix = 'plugins\nested' }; Pattern = 'must be a relative forward-slash path' }
            @{ Label = 'an empty path prefix'; Parameters = @{ Tag = 'plugins-v1.2.3'; PathPrefix = '/' }; Pattern = 'must be a relative forward-slash path' }
        ) {
            { New-PluginReleaseLocator @Parameters } | Should -Throw -ExpectedMessage "*$Pattern*"
        }
    }
}

Describe 'New-MarketplaceManifestContent' -Tag 'Unit' {
    BeforeAll {
        $script:unsortedEntries = @(
            [ordered]@{
                name    = 'rpi'
                source  = [ordered]@{ source = 'github'; repo = 'contoso/contoso-hve'; path = 'plugins/rpi'; ref = 'plugins-v9.9.9' }
                version = '9.9.9'
                agents  = @('agents/rpi/rpi-planner.md')
                'x-hve' = [ordered]@{
                    displayName       = 'Contoso - rpi'
                    documentation     = 'docs/plugins/rpi.md'
                    componentMaturity = [ordered]@{ 'agents/rpi/rpi-planner.md' = 'preview' }
                    profiles          = [ordered]@{ starter = @('agents/rpi/rpi-planner.md') }
                }
            }
            [ordered]@{
                name    = 'ado'
                source  = [ordered]@{ source = 'github'; repo = 'contoso/contoso-hve'; path = 'plugins/ado'; ref = 'plugins-v9.9.9' }
                version = '9.9.9'
                'x-hve' = [ordered]@{ displayName = 'Contoso - ado'; documentation = 'docs/plugins/ado.md' }
            }
        )
        $script:projected = New-MarketplaceManifestContent -RepoName 'contoso-hve' -Description 'Contoso HVE' `
            -Version '9.9.9' -OwnerName 'Contoso' -Plugins $script:unsortedEntries
    }

    Context 'when projecting catalog entries without a release locator' {
        It 'Emits catalog keys in a fixed order' {
            @($script:projected.Keys) | Should -Be @('name', 'metadata', 'owner', 'plugins')
        }

        It 'Emits catalog metadata and owner' {
            @($script:projected['metadata'].Keys) | Should -Be @('description', 'version', 'pluginRoot')
            $script:projected['metadata']['pluginRoot'] | Should -BeExactly './plugins'
            $script:projected['owner']['name'] | Should -BeExactly 'Contoso'
        }

        It 'Sorts entries by package name' {
            @($script:projected['plugins'] | ForEach-Object { $_['name'] }) | Should -Be @('ado', 'rpi')
        }

        It 'Preserves standard component fields and the catalog overlay' {
            $rpiEntry = @($script:projected['plugins'] | Where-Object { $_['name'] -eq 'rpi' })[0]
            @($rpiEntry['agents']) | Should -Be @('agents/rpi/rpi-planner.md')
            $rpiEntry['x-hve']['displayName'] | Should -BeExactly 'Contoso - rpi'
            $rpiEntry['x-hve']['documentation'] | Should -BeExactly 'docs/plugins/rpi.md'
        }

        It 'Retains the lifecycle and profile policy in the snapshot' {
            $rpiEntry = @($script:projected['plugins'] | Where-Object { $_['name'] -eq 'rpi' })[0]
            $rpiEntry['x-hve']['componentMaturity']['agents/rpi/rpi-planner.md'] | Should -BeExactly 'preview'
            @($rpiEntry['x-hve']['profiles']['starter']) | Should -Be @('agents/rpi/rpi-planner.md')
        }

        It 'Keeps the declared object source unchanged' {
            $adoEntry = @($script:projected['plugins'] | Where-Object { $_['name'] -eq 'ado' })[0]
            $adoEntry['source']['ref'] | Should -BeExactly 'plugins-v9.9.9'
            $adoEntry['source']['path'] | Should -BeExactly 'plugins/ado'
        }
    }

    Context 'when a release locator is supplied' {
        BeforeAll {
            $script:pinned = New-MarketplaceManifestContent -RepoName 'contoso-hve' -Description 'Contoso HVE' `
                -Version '9.9.9' -OwnerName 'Contoso' -Plugins $script:unsortedEntries `
                -ReleaseLocator (New-PluginReleaseLocator -Tag 'plugins-v4.5.6' -Repo 'contoso/contoso-hve' -PathPrefix 'packages')
            $script:pinnedJson = $script:pinned | ConvertTo-Json -Depth 12
        }

        It 'Rewrites every entry source to the immutable reference' {
            foreach ($entry in $script:pinned['plugins']) {
                @($entry['source'].Keys) | Should -Be @('source', 'repo', 'path', 'ref')
                $entry['source']['source'] | Should -BeExactly 'github'
                $entry['source']['repo'] | Should -BeExactly 'contoso/contoso-hve'
                $entry['source']['ref'] | Should -BeExactly 'plugins-v4.5.6'
                $entry['source']['path'] | Should -BeExactly "packages/$($entry['name'])"
            }
        }

        It 'Serializes without a sha locator field' {
            $script:pinnedJson | Should -Not -Match '"sha"'
        }

        It 'Retains the lifecycle and profile policy through the pinned projection' {
            $rpiEntry = @($script:pinned['plugins'] | Where-Object { $_['name'] -eq 'rpi' })[0]
            $rpiEntry['x-hve']['componentMaturity']['agents/rpi/rpi-planner.md'] | Should -BeExactly 'preview'
            @($rpiEntry['x-hve']['profiles']['starter']) | Should -Be @('agents/rpi/rpi-planner.md')
        }
    }

    Context 'when an entry declares a bare package source' {
        It 'Refuses the projection' {
            $bareEntries = @([ordered]@{ name = 'rpi'; source = 'rpi'; version = '9.9.9' })
            { New-MarketplaceManifestContent -RepoName 'contoso-hve' -Description 'Contoso HVE' `
                    -Version '9.9.9' -OwnerName 'Contoso' -Plugins $bareEntries } |
                Should -Throw -ExpectedMessage '*must be an immutable object locator*'
        }
    }
}

Describe 'Write-MarketplaceManifest' -Tag 'Unit' {
    BeforeEach {
        $script:repoRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-PluginFixtureRepository -Path $script:repoRoot -Version '9.9.9' | Out-Null
        $script:catalogEntries = @(
            New-PluginFixtureEntry -Name 'rpi' -Description 'RPI workflow' -Version '9.9.9' -Agents @('agents/rpi/rpi-planner.md')
            New-PluginFixtureEntry -Name 'ado' -Description 'ADO workflow' -Version '9.9.9'
        )
        Add-PluginFixtureCatalog -RepoRoot $script:repoRoot -Entries $script:catalogEntries -Version '9.9.9' | Out-Null
        $script:catalog = Get-Content -LiteralPath (Join-Path $script:repoRoot '.github/plugin/marketplace.json') -Raw |
            ConvertFrom-Json -AsHashtable
        $script:productionPath = Join-Path $script:repoRoot '.github/plugin/marketplace.json'
        $script:productionBytesBefore = [System.IO.File]::ReadAllBytes($script:productionPath)
    }

    Context 'when writing a snapshot to an explicit destination' {
        BeforeEach {
            $script:snapshotPath = Join-Path $script:repoRoot 'out/snapshot/marketplace.json'
            Write-MarketplaceManifest -RepoRoot $script:repoRoot -Catalog $script:catalog `
                -ReleaseLocator (New-PluginReleaseLocator -Tag 'plugins-v4.5.6' -Repo 'contoso/contoso-hve') `
                -OutputPath 'out/snapshot/marketplace.json'
            $script:snapshotText = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($script:snapshotPath))
        }

        It 'Creates the destination directory and file' {
            Test-Path -LiteralPath $script:snapshotPath -PathType Leaf | Should -BeTrue
        }

        It 'Terminates the file with exactly one trailing newline' {
            $script:snapshotText | Should -Match "\}\n$"
            $script:snapshotText | Should -Not -Match "\n\n$"
        }

        It 'Pins every entry source to the immutable reference' {
            $snapshot = $script:snapshotText | ConvertFrom-Json -AsHashtable
            @($snapshot['plugins'] | ForEach-Object { $_['source']['ref'] }) | Should -Be @('plugins-v4.5.6', 'plugins-v4.5.6')
            @($snapshot['plugins'] | ForEach-Object { $_['name'] }) | Should -Be @('ado', 'rpi')
        }

        It 'Records no sha locator field' {
            $script:snapshotText | Should -Not -Match '"sha"'
        }

        It 'Leaves the production catalog byte-identical' {
            [System.IO.File]::ReadAllBytes($script:productionPath) | Should -Be $script:productionBytesBefore
        }
    }

    Context 'when the destination is the production catalog' {
        It 'Refuses a <Label> destination' -ForEach @(
            @{ Label = 'repository-relative'; UseAbsolute = $false }
            @{ Label = 'absolute'; UseAbsolute = $true }
        ) {
            $destination = if ($UseAbsolute) { $script:productionPath } else { '.github/plugin/marketplace.json' }
            { Write-MarketplaceManifest -RepoRoot $script:repoRoot -Catalog $script:catalog -OutputPath $destination } |
                Should -Throw -ExpectedMessage '*must not write the production catalog*'
            [System.IO.File]::ReadAllBytes($script:productionPath) | Should -Be $script:productionBytesBefore
        }
    }

    Context 'when running as a dry run' {
        It 'Writes nothing to disk' {
            Write-MarketplaceManifest -RepoRoot $script:repoRoot -Catalog $script:catalog `
                -OutputPath 'out/dryrun/marketplace.json' -DryRun
            Test-Path -LiteralPath (Join-Path $script:repoRoot 'out/dryrun') | Should -BeFalse
            [System.IO.File]::ReadAllBytes($script:productionPath) | Should -Be $script:productionBytesBefore
        }
    }
}

Describe 'Assert-PluginSnapshotTarget' -Tag 'Unit' {
    Context 'when the target is a disposable branch and tag pair' {
        BeforeAll {
            $script:target = Assert-PluginSnapshotTarget -Branch 'plugins-snapshot/run-42' -Tag 'plugins-snapshot/run-42-tag'
        }

        It 'Echoes the validated branch and tag' {
            $script:target.Branch | Should -BeExactly 'plugins-snapshot/run-42'
            $script:target.Tag | Should -BeExactly 'plugins-snapshot/run-42-tag'
        }

        It 'Returns exact push refspecs' {
            @($script:target.RefSpecs) | Should -Be @(
                'HEAD:refs/heads/plugins-snapshot/run-42',
                'refs/tags/plugins-snapshot/run-42-tag'
            )
        }

        It 'Ignores unrelated existing references' {
            $target = Assert-PluginSnapshotTarget -Branch 'plugins-snapshot/run-43' -Tag 'plugins-snapshot/run-43-tag' `
                -ExistingRefs @('refs/heads/main', 'refs/tags/plugins-v1.0.0', 'plugins-snapshot/run-42-tag')
            $target.Tag | Should -BeExactly 'plugins-snapshot/run-43-tag'
        }
    }

    Context 'when the target is a production snapshot tag' {
        It 'Returns exactly one immutable tag refspec' {
            $target = Assert-PluginSnapshotTarget -Mode Production -Branch '' -Tag 'plugins-v4.5.6'
            $target.Branch | Should -BeNullOrEmpty
            $target.Tag | Should -BeExactly 'plugins-v4.5.6'
            @($target.RefSpecs) | Should -Be @('refs/tags/plugins-v4.5.6')
        }

        It 'Refuses an existing production tag' {
            { Assert-PluginSnapshotTarget -Mode Production -Branch '' -Tag 'plugins-v4.5.6' `
                    -ExistingRefs @('refs/tags/plugins-v4.5.6') } |
                Should -Throw -ExpectedMessage '*Tags are immutable and are never overwritten*'
        }

        It 'Refuses a non-production tag' {
            { Assert-PluginSnapshotTarget -Mode Production -Branch '' -Tag 'plugins-snapshot/run-1-tag' } |
                Should -Throw -ExpectedMessage "*must use 'plugins-v<version>' form*"
        }
    }

    Context 'when the target names a protected or invalid reference' {
        It 'Refuses <Label>' -ForEach @(
            @{ Label = 'the default branch'; Branch = 'main'; Tag = 'plugins-snapshot/run-1-tag'; Pattern = 'targets a protected production reference' }
            @{ Label = 'the moving release branch'; Branch = 'release/plugins'; Tag = 'plugins-snapshot/run-1-tag'; Pattern = 'targets a protected production reference' }
            @{ Label = 'a production release tag'; Branch = 'plugins-snapshot/run-1'; Tag = 'plugins-v1.2.3'; Pattern = 'targets a protected production reference' }
            @{ Label = 'a branch outside the disposable prefix'; Branch = 'feature/run-1'; Tag = 'plugins-snapshot/run-1-tag'; Pattern = "must start with the disposable prefix" }
            @{ Label = 'a tag outside the disposable prefix'; Branch = 'plugins-snapshot/run-1'; Tag = 'snapshot/run-1'; Pattern = "must start with the disposable prefix" }
            @{ Label = 'an empty branch'; Branch = ''; Tag = 'plugins-snapshot/run-1-tag'; Pattern = 'is not a valid git reference name' }
            @{ Label = 'a branch with whitespace'; Branch = 'plugins-snapshot/run 1'; Tag = 'plugins-snapshot/run-1-tag'; Pattern = 'is not a valid git reference name' }
            @{ Label = 'a tag with a double dot'; Branch = 'plugins-snapshot/run-1'; Tag = 'plugins-snapshot/run..1'; Pattern = 'is not a valid git reference name' }
            @{ Label = 'a tag with a lock suffix'; Branch = 'plugins-snapshot/run-1'; Tag = 'plugins-snapshot/run-1.lock'; Pattern = 'is not a valid git reference name' }
        ) {
            { Assert-PluginSnapshotTarget -Branch $Branch -Tag $Tag } | Should -Throw -ExpectedMessage "*$Pattern*"
        }
    }

    Context 'when the branch and tag are not distinct' {
        It 'Refuses the target' {
            { Assert-PluginSnapshotTarget -Branch 'plugins-snapshot/run-1' -Tag 'plugins-snapshot/run-1' } |
                Should -Throw -ExpectedMessage '*branch and tag must differ*'
        }
    }

    Context 'when the tag already exists on the remote' {
        It 'Refuses a <Label> existing tag' -ForEach @(
            @{ Label = 'short-form'; ExistingRefs = @('plugins-snapshot/run-1-tag') }
            @{ Label = 'fully-qualified'; ExistingRefs = @('refs/tags/plugins-snapshot/run-1-tag') }
        ) {
            { Assert-PluginSnapshotTarget -Branch 'plugins-snapshot/run-1' -Tag 'plugins-snapshot/run-1-tag' -ExistingRefs $ExistingRefs } |
                Should -Throw -ExpectedMessage '*Tags are immutable and are never overwritten*'
        }
    }
}

AfterAll {
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
}
