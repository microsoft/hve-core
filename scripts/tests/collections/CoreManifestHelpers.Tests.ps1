#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $modulePath = Join-Path $script:RepoRoot 'scripts/collections/Modules/CoreManifestHelpers.psm1'
    Import-Module $modulePath -Force

    $script:CoreManifest = Read-CoreManifest -ManifestPath (Join-Path $script:RepoRoot 'collections/core-manifest.yml')
    $script:CollectionsMap = Get-CoreManifestProperty -InputObject $script:CoreManifest -Name 'collections'
    $script:CollectionIds = @(Get-CoreManifestKeys -InputObject $script:CollectionsMap)
    $script:PlainCollectionId = 'coding-standards'
    $script:CautionCollectionId = 'data-science'
    $script:ArtifactSections = @(Get-CoreManifestArtifactSectionNames)
}

Describe 'ConvertTo-CollectionManifestFromCore' {
    Context 'when projecting a plain collection' {
        BeforeAll {
            $script:PlainManifest = ConvertTo-CollectionManifestFromCore `
                -CoreManifest $script:CoreManifest `
                -CollectionId $script:PlainCollectionId `
                -RepoRoot $script:RepoRoot
        }

        It 'returns an ordered dictionary with the requested id' {
            $script:PlainManifest | Should -BeOfType [System.Collections.IDictionary]
            $script:PlainManifest.id | Should -Be $script:PlainCollectionId
        }

        It 'copies the name from the core manifest metadata' {
            $metadata = Get-CoreManifestProperty -InputObject $script:CollectionsMap -Name $script:PlainCollectionId
            $expectedName = [string](Get-CoreManifestProperty -InputObject $metadata -Name 'name')
            $script:PlainManifest.name | Should -Be $expectedName
        }

        It 'contains the expected top-level keys' {
            $keys = @($script:PlainManifest.Keys)
            $keys | Should -Contain 'id'
            $keys | Should -Contain 'name'
            $keys | Should -Contain 'descriptions'
            $keys | Should -Contain 'tags'
            $keys | Should -Contain 'items'
            $keys | Should -Contain 'display'
        }

        It 'returns at least one item' {
            @($script:PlainManifest.items).Count | Should -BeGreaterThan 0
        }

        It 'projects every item with path, kind, and maturity keys' {
            foreach ($item in $script:PlainManifest.items) {
                $itemKeys = @((Get-CoreManifestKeys -InputObject $item))
                $itemKeys | Should -Contain 'path'
                $itemKeys | Should -Contain 'kind'
                $itemKeys | Should -Contain 'maturity'
                [string](Get-CoreManifestProperty -InputObject $item -Name 'path') | Should -Not -BeNullOrEmpty
                [string](Get-CoreManifestProperty -InputObject $item -Name 'kind') | Should -Not -BeNullOrEmpty
            }
        }

        It 'only includes artifacts whose collections membership contains the requested id' {
            $artifactCollectionMap = @{}
            foreach ($section in $script:ArtifactSections) {
                $sectionArtifacts = Get-CoreManifestProperty -InputObject $script:CoreManifest -Name $section
                foreach ($artifactKey in (Get-CoreManifestKeys -InputObject $sectionArtifacts)) {
                    $artifact = Get-CoreManifestProperty -InputObject $sectionArtifacts -Name $artifactKey
                    $path = [string](Get-CoreManifestProperty -InputObject $artifact -Name 'path')
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = $artifactKey }
                    $normalized = ConvertTo-CoreManifestRelativePath -Path $path
                    $memberships = @(Get-CoreManifestProperty -InputObject $artifact -Name 'collections')
                    $artifactCollectionMap[$normalized] = $memberships
                }
            }

            foreach ($item in $script:PlainManifest.items) {
                $itemPath = [string](Get-CoreManifestProperty -InputObject $item -Name 'path')
                $artifactCollectionMap.ContainsKey($itemPath) | Should -BeTrue -Because "item '$itemPath' should map to a manifest artifact"
                $artifactCollectionMap[$itemPath] | Should -Contain $script:PlainCollectionId
            }
        }
    }

    Context 'when applying deterministic ordering rules' {
        BeforeAll {
            $script:OrderedManifest = ConvertTo-CollectionManifestFromCore `
                -CoreManifest $script:CoreManifest `
                -CollectionId $script:PlainCollectionId `
                -RepoRoot $script:RepoRoot
            $script:OrderedItems = @($script:OrderedManifest.items)
            $script:KindOrder = @('agent', 'prompt', 'instruction', 'skill')
        }

        It 'groups items by kind in agents, prompts, instructions, skills order' {
            $kindRanks = @($script:OrderedItems | ForEach-Object {
                    $kind = [string](Get-CoreManifestProperty -InputObject $_ -Name 'kind')
                    $script:KindOrder.IndexOf($kind)
                })
            $kindRanks | Should -Not -Contain -1
            for ($i = 1; $i -lt $kindRanks.Count; $i++) {
                $kindRanks[$i] | Should -BeGreaterOrEqual $kindRanks[$i - 1] -Because 'kinds must remain grouped in the canonical section order'
            }
        }

        It 'orders items within each kind by ordinal path comparison' {
            $grouped = $script:OrderedItems | Group-Object -Property {
                [string](Get-CoreManifestProperty -InputObject $_ -Name 'kind')
            }
            foreach ($group in $grouped) {
                $paths = @($group.Group | ForEach-Object {
                        [string](Get-CoreManifestProperty -InputObject $_ -Name 'path')
                    })
                for ($i = 1; $i -lt $paths.Count; $i++) {
                    [System.String]::CompareOrdinal($paths[$i - 1], $paths[$i]) |
                        Should -BeLessThan 0 -Because "paths '$($paths[$i - 1])' and '$($paths[$i])' should be in ascending ordinal order"
                }
            }
        }

        It 'produces an identical item sequence on repeated projections' {
            $first = @($script:OrderedItems | ForEach-Object {
                    [string](Get-CoreManifestProperty -InputObject $_ -Name 'path')
                })
            $repeat = ConvertTo-CollectionManifestFromCore `
                -CoreManifest $script:CoreManifest `
                -CollectionId $script:PlainCollectionId `
                -RepoRoot $script:RepoRoot
            $second = @($repeat.items | ForEach-Object {
                    [string](Get-CoreManifestProperty -InputObject $_ -Name 'path')
                })
            $second | Should -Be $first
        }

        It 'produces an identical item sequence when artifact declaration order is shuffled' {
            $baseline = @($script:OrderedItems | ForEach-Object {
                    [string](Get-CoreManifestProperty -InputObject $_ -Name 'path')
                })

            # Rebuild the core manifest with each artifact section's keys reversed,
            # simulating a different declaration order in the YAML source. A correct
            # deterministic ordering rule must ignore declaration order entirely.
            $shuffled = [ordered]@{}
            foreach ($key in (Get-CoreManifestKeys -InputObject $script:CoreManifest)) {
                $shuffled[$key] = $script:CoreManifest[$key]
            }
            foreach ($section in $script:ArtifactSections) {
                $sectionArtifacts = Get-CoreManifestProperty -InputObject $script:CoreManifest -Name $section
                $sectionKeys = @(Get-CoreManifestKeys -InputObject $sectionArtifacts)
                [array]::Reverse($sectionKeys)
                $reversed = [ordered]@{}
                foreach ($artifactKey in $sectionKeys) {
                    $reversed[$artifactKey] = $sectionArtifacts[$artifactKey]
                }
                $shuffled[$section] = $reversed
            }

            $shuffledManifest = ConvertTo-CollectionManifestFromCore `
                -CoreManifest $shuffled `
                -CollectionId $script:PlainCollectionId `
                -RepoRoot $script:RepoRoot
            $shuffledPaths = @($shuffledManifest.items | ForEach-Object {
                    [string](Get-CoreManifestProperty -InputObject $_ -Name 'path')
                })

            $shuffledPaths | Should -Be $baseline
        }
    }

    Context 'when projecting a caution-bearing collection' {
        It 'returns an items collection scoped to the caution collection' {
            $manifest = ConvertTo-CollectionManifestFromCore `
                -CoreManifest $script:CoreManifest `
                -CollectionId $script:CautionCollectionId `
                -RepoRoot $script:RepoRoot
            $manifest.id | Should -Be $script:CautionCollectionId
            @($manifest.items).Count | Should -BeGreaterThan 0
        }
    }

    Context 'when a member artifact is non-shippable' {
        BeforeAll {
            $script:SecurityManifest = ConvertTo-CollectionManifestFromCore `
                -CoreManifest $script:CoreManifest `
                -CollectionId 'security' `
                -RepoRoot $script:RepoRoot
            $script:SecurityItemPaths = @($script:SecurityManifest.items | ForEach-Object {
                    [string](Get-CoreManifestProperty -InputObject $_ -Name 'path')
                })
        }

        It 'excludes artifacts whose maturity is removed or deprecated' {
            $script:SecurityItemPaths | Should -Not -Contain '.github/skills/security/owasp-docker'
        }

        It 'retains shippable experimental artifacts' {
            $script:SecurityItemPaths | Should -Contain '.github/skills/security/owasp-agentic'
        }

        It 'projects only items with a shippable maturity rank' {
            foreach ($item in $script:SecurityManifest.items) {
                $maturity = [string](Get-CoreManifestProperty -InputObject $item -Name 'maturity')
                Get-CoreManifestMaturityRank -Maturity $maturity | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'when -All is used' {
        BeforeAll {
            $script:AllManifests = @(ConvertTo-CollectionManifestFromCore `
                    -CoreManifest $script:CoreManifest `
                    -All `
                    -RepoRoot $script:RepoRoot)
        }

        It 'returns one projection per collection declared in the core manifest' {
            $script:AllManifests.Count | Should -Be $script:CollectionIds.Count
        }

        It 'preserves the same set of collection ids' {
            $projectedIds = @($script:AllManifests | ForEach-Object { $_.id } | Sort-Object)
            $expectedIds = @($script:CollectionIds | Sort-Object)
            $projectedIds | Should -Be $expectedIds
        }
    }

    Context 'when the collection id is not declared' {
        It 'throws a descriptive error' {
            {
                ConvertTo-CollectionManifestFromCore `
                    -CoreManifest $script:CoreManifest `
                    -CollectionId 'does-not-exist-collection-id' `
                    -RepoRoot $script:RepoRoot
            } | Should -Throw -ExpectedMessage "*does-not-exist-collection-id*"
        }
    }
}

Describe 'New-CollectionReadmeBodyFromCore' {
    Context 'for a plain collection' {
        BeforeAll {
            $script:PlainBody = New-CollectionReadmeBodyFromCore `
                -CoreManifest $script:CoreManifest `
                -CollectionId $script:PlainCollectionId `
                -RepoRoot $script:RepoRoot
        }

        It 'begins with a level-one heading containing the collection title' {
            $metadata = Get-CoreManifestProperty -InputObject $script:CollectionsMap -Name $script:PlainCollectionId
            $title = [string](Get-CoreManifestProperty -InputObject $metadata -Name 'name')
            $firstLine = ($script:PlainBody -split "`r?`n")[0]
            $firstLine | Should -Be "# $title"
        }

        It 'omits the Channel distribution heading' {
            $script:PlainBody | Should -Not -Match '(?m)^## Channel distribution\s*$'
        }

        It 'includes the Included Artifacts heading followed by the auto-generated markers in order' {
            $script:PlainBody | Should -Match '(?m)^## Included Artifacts\s*$'
            $script:PlainBody | Should -Match '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
            $script:PlainBody | Should -Match '<!-- END AUTO-GENERATED ARTIFACTS -->'

            $artifactsIndex = $script:PlainBody.IndexOf('## Included Artifacts')
            $beginIndex = $script:PlainBody.IndexOf('<!-- BEGIN AUTO-GENERATED ARTIFACTS -->')
            $endIndex = $script:PlainBody.IndexOf('<!-- END AUTO-GENERATED ARTIFACTS -->')
            $artifactsIndex | Should -BeLessThan $beginIndex
            $beginIndex | Should -BeLessThan $endIndex
        }

        It 'does not contain a caution admonition' {
            $script:PlainBody | Should -Not -Match '\[\!CAUTION\]'
        }
    }

    Context 'for a caution-bearing collection' {
        BeforeAll {
            $script:CautionBody = New-CollectionReadmeBodyFromCore `
                -CoreManifest $script:CoreManifest `
                -CollectionId $script:CautionCollectionId `
                -RepoRoot $script:RepoRoot
        }

        It 'contains a CAUTION admonition block' {
            $script:CautionBody | Should -Match '(?m)^> \[\!CAUTION\]\s*$'
        }

        It 'follows the admonition with at least one blockquote-prefixed line' {
            $lines = $script:CautionBody -split "`r?`n"
            $cautionIndex = [Array]::FindIndex($lines, [Predicate[string]] { param($l) $l -match '^> \[\!CAUTION\]\s*$' })
            $cautionIndex | Should -BeGreaterThan -1
            $lines[$cautionIndex + 1] | Should -Match '^> .+'
        }

        It 'omits the Channel distribution section but keeps the Included Artifacts sections' {
            $script:CautionBody | Should -Not -Match '(?m)^## Channel distribution\s*$'
            $script:CautionBody | Should -Match '(?m)^## Included Artifacts\s*$'
            $script:CautionBody | Should -Match '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
            $script:CautionBody | Should -Match '<!-- END AUTO-GENERATED ARTIFACTS -->'
        }
    }

    Context 'when the collection contains experimental shippable assets' {
        BeforeAll {
            $script:ExperimentalBody = New-CollectionReadmeBodyFromCore `
                -CoreManifest $script:CoreManifest `
                -CollectionId 'security' `
                -RepoRoot $script:RepoRoot
        }

        It 'emits the generic Experimental callout after the intro and before Included Artifacts' {
            $script:ExperimentalBody | Should -Match '(?m)^> Experimental: This collection includes experimental assets that may change significantly\.\s*$'
            $calloutIndex = $script:ExperimentalBody.IndexOf('> Experimental:')
            $artifactsIndex = $script:ExperimentalBody.IndexOf('## Included Artifacts')
            $calloutIndex | Should -BeGreaterThan -1
            $calloutIndex | Should -BeLessThan $artifactsIndex
        }

        It 'excludes non-shippable artifacts from the markdown body' {
            $script:ExperimentalBody | Should -Not -Match 'owasp-docker'
        }
    }

    Context 'when the collection is all stable' {
        It 'does not emit a maturity callout' {
            $collection = [ordered]@{
                items = @(
                    [ordered]@{ path = 'a'; kind = 'agent'; maturity = 'stable' }
                    [ordered]@{ path = 'b'; kind = 'prompt'; maturity = 'stable' }
                )
            }
            Get-CoreCollectionMaturityCallout -Collection $collection | Should -BeNullOrEmpty
        }
    }

    Context 'when the collection id is not declared' {
        It 'throws a descriptive error' {
            {
                New-CollectionReadmeBodyFromCore `
                    -CoreManifest $script:CoreManifest `
                    -CollectionId 'does-not-exist-collection-id' `
                    -RepoRoot $script:RepoRoot
            } | Should -Throw -ExpectedMessage "*does-not-exist-collection-id*"
        }
    }
}
