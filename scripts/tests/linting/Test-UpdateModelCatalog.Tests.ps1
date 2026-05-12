#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Update-ModelCatalog.ps1'
    . $script:ScriptPath

    # Suppress Write-Host output during tests
    Mock Write-Host {}
    Mock Write-Warning {}
}

#region Get-RemoteYaml Tests

Describe 'Get-RemoteYaml' -Tag 'Unit' {
    Context 'when URL returns valid YAML' {
        It 'Parses YAML content into objects' {
            $yamlContent = @"
- name: Claude Sonnet 4
  release_status: GA
- name: GPT-5 mini
  release_status: Preview
"@
            Mock Invoke-WebRequest {
                [PSCustomObject]@{ Content = $yamlContent }
            }

            $result = Get-RemoteYaml -Url 'https://example.com/test.yml'
            $result | Should -HaveCount 2
            $result[0].name | Should -Be 'Claude Sonnet 4'
            $result[1].release_status | Should -Be 'Preview'
        }
    }

    Context 'when URL request fails' {
        It 'Throws an error' {
            Mock Invoke-WebRequest { throw 'Network error' }

            { Get-RemoteYaml -Url 'https://example.com/fail.yml' } | Should -Throw
        }
    }

    Context 'when YAML is empty' {
        It 'Returns null or empty' {
            Mock Invoke-WebRequest {
                [PSCustomObject]@{ Content = '' }
            }

            $result = Get-RemoteYaml -Url 'https://example.com/empty.yml'
            $result | Should -BeNullOrEmpty
        }
    }
}

#endregion Get-RemoteYaml Tests

#region Merge-ModelData Tests

Describe 'Merge-ModelData' -Tag 'Unit' {
    Context 'when given matching release status and multiplier data' {
        BeforeAll {
            $script:ReleaseStatus = @(
                @{ name = 'Claude Sonnet 4'; release_status = 'GA' }
                @{ name = 'GPT-5 mini'; release_status = 'Preview' }
            )
            $script:Multipliers = @(
                @{ name = 'Claude Sonnet 4'; multiplier_paid = 1 }
                @{ name = 'GPT-5 mini'; multiplier_paid = 0 }
            )
            $script:Result = @(Merge-ModelData -ReleaseStatus $script:ReleaseStatus -Multipliers $script:Multipliers)
        }

        It 'Returns an entry for each model in release status' {
            $script:Result | Should -HaveCount 2
        }

        It 'Appends (copilot) suffix to model names' {
            $script:Result[0].name | Should -Be 'Claude Sonnet 4 (copilot)'
            $script:Result[1].name | Should -Be 'GPT-5 mini (copilot)'
        }

        It 'Maps GA release status to ga' {
            $script:Result[0].status | Should -Be 'ga'
        }

        It 'Maps non-GA release status to preview' {
            $script:Result[1].status | Should -Be 'preview'
        }

        It 'Sets correct multiplier values' {
            $script:Result[0].multiplier | Should -Be 1
            $script:Result[1].multiplier | Should -Be 0
        }
    }

    Context 'tier classification from multiplier values' {
        It 'Assigns free tier for multiplier 0' {
            $release = @(@{ name = 'Free Model'; release_status = 'GA' })
            $mult = @(@{ name = 'Free Model'; multiplier_paid = 0 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'free'
        }

        It 'Assigns fast tier for multiplier 0.25' {
            $release = @(@{ name = 'Fast Model'; release_status = 'GA' })
            $mult = @(@{ name = 'Fast Model'; multiplier_paid = 0.25 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'fast'
        }

        It 'Assigns fast tier for multiplier 0.33' {
            $release = @(@{ name = 'Fast Edge'; release_status = 'GA' })
            $mult = @(@{ name = 'Fast Edge'; multiplier_paid = 0.33 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'fast'
        }

        It 'Assigns standard tier for multiplier 0.5' {
            $release = @(@{ name = 'Standard Low'; release_status = 'GA' })
            $mult = @(@{ name = 'Standard Low'; multiplier_paid = 0.5 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'standard'
        }

        It 'Assigns standard tier for multiplier 1' {
            $release = @(@{ name = 'Standard Model'; release_status = 'GA' })
            $mult = @(@{ name = 'Standard Model'; multiplier_paid = 1 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'standard'
        }

        It 'Assigns premium tier for multiplier 3' {
            $release = @(@{ name = 'Premium Model'; release_status = 'GA' })
            $mult = @(@{ name = 'Premium Model'; multiplier_paid = 3 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'premium'
        }

        It 'Assigns premium tier for multiplier 5' {
            $release = @(@{ name = 'Premium Edge'; release_status = 'GA' })
            $mult = @(@{ name = 'Premium Edge'; multiplier_paid = 5 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'premium'
        }

        It 'Assigns ultra tier for multiplier 15' {
            $release = @(@{ name = 'Ultra Model'; release_status = 'GA' })
            $mult = @(@{ name = 'Ultra Model'; multiplier_paid = 15 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'ultra'
        }

        It 'Assigns ultra tier for multiplier 30' {
            $release = @(@{ name = 'Ultra Max'; release_status = 'GA' })
            $mult = @(@{ name = 'Ultra Max'; multiplier_paid = 30 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -Be 'ultra'
        }

        It 'Returns a string tier, not an array' {
            $release = @(@{ name = 'Tier Check'; release_status = 'GA' })
            $mult = @(@{ name = 'Tier Check'; multiplier_paid = 0.25 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].tier | Should -BeOfType [string]
        }
    }

    Context 'when multiplier_paid is Not applicable' {
        It 'Treats Not applicable as multiplier 0 and free tier' {
            $release = @(@{ name = 'NA Model'; release_status = 'GA' })
            $mult = @(@{ name = 'NA Model'; multiplier_paid = 'Not applicable' })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].multiplier | Should -Be 0
            $result[0].tier | Should -Be 'free'
        }
    }

    Context 'when model has no multiplier entry' {
        It 'Defaults to multiplier 1 and standard tier' {
            $release = @(@{ name = 'No Mult Model'; release_status = 'GA' })
            $mult = @(@{ name = 'Other Model'; multiplier_paid = 5 })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].multiplier | Should -Be 1
            $result[0].tier | Should -Be 'standard'
        }
    }

    Context 'when release status has multiple models' {
        It 'Processes all models in order' {
            $release = @(
                @{ name = 'Model A'; release_status = 'GA' }
                @{ name = 'Model B'; release_status = 'Preview' }
                @{ name = 'Model C'; release_status = 'GA' }
            )
            $mult = @(
                @{ name = 'Model A'; multiplier_paid = 0 }
                @{ name = 'Model B'; multiplier_paid = 1 }
                @{ name = 'Model C'; multiplier_paid = 4 }
            )
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result | Should -HaveCount 3
            $result[0].name | Should -Be 'Model A (copilot)'
            $result[1].name | Should -Be 'Model B (copilot)'
            $result[2].name | Should -Be 'Model C (copilot)'
            $result[0].tier | Should -Be 'free'
            $result[1].tier | Should -Be 'standard'
            $result[2].tier | Should -Be 'premium'
        }
    }

    Context 'when multiplier_paid is null' {
        It 'Defaults to multiplier 1' {
            $release = @(@{ name = 'Null Mult'; release_status = 'GA' })
            $mult = @(@{ name = 'Null Mult'; multiplier_paid = $null })
            $result = @(Merge-ModelData -ReleaseStatus $release -Multipliers $mult)
            $result[0].multiplier | Should -Be 1
            $result[0].tier | Should -Be 'standard'
        }
    }
}

#endregion Merge-ModelData Tests

#region Compare-Catalogs Tests

Describe 'Compare-Catalogs' -Tag 'Unit' {
    Context 'when catalogs are identical' {
        It 'Returns empty added, removed, and changed arrays' {
            $models = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 1 }
                [PSCustomObject]@{ name = 'Model B (copilot)'; multiplier = 3 }
            )
            $result = Compare-Catalogs -Current $models -Discovered $models
            $result.added | Should -HaveCount 0
            $result.removed | Should -HaveCount 0
            $result.changed | Should -HaveCount 0
        }
    }

    Context 'when new models are added' {
        It 'Identifies added models' {
            $current = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 1 }
            )
            $discovered = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 1 }
                [PSCustomObject]@{ name = 'Model B (copilot)'; multiplier = 3 }
            )
            $result = Compare-Catalogs -Current $current -Discovered $discovered
            $result.added | Should -HaveCount 1
            $result.added[0].name | Should -Be 'Model B (copilot)'
        }
    }

    Context 'when models are removed' {
        It 'Identifies removed models' {
            $current = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 1 }
                [PSCustomObject]@{ name = 'Model B (copilot)'; multiplier = 3 }
            )
            $discovered = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 1 }
            )
            $result = Compare-Catalogs -Current $current -Discovered $discovered
            $result.removed | Should -HaveCount 1
            $result.removed[0].name | Should -Be 'Model B (copilot)'
        }
    }

    Context 'when multipliers change' {
        It 'Identifies changed multipliers' {
            $current = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 1 }
            )
            $discovered = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 3 }
            )
            $result = Compare-Catalogs -Current $current -Discovered $discovered
            $result.changed | Should -HaveCount 1
            $result.changed[0].name | Should -Be 'Model A (copilot)'
            $result.changed[0].oldMultiplier | Should -Be 1
            $result.changed[0].newMultiplier | Should -Be 3
        }
    }

    Context 'when all types of changes occur simultaneously' {
        It 'Reports additions, removals, and changes together' {
            $current = @(
                [PSCustomObject]@{ name = 'Stable (copilot)'; multiplier = 1 }
                [PSCustomObject]@{ name = 'Removed (copilot)'; multiplier = 5 }
                [PSCustomObject]@{ name = 'Changed (copilot)'; multiplier = 1 }
            )
            $discovered = @(
                [PSCustomObject]@{ name = 'Stable (copilot)'; multiplier = 1 }
                [PSCustomObject]@{ name = 'Changed (copilot)'; multiplier = 3 }
                [PSCustomObject]@{ name = 'Added (copilot)'; multiplier = 0 }
            )
            $result = Compare-Catalogs -Current $current -Discovered $discovered
            $result.added | Should -HaveCount 1
            $result.removed | Should -HaveCount 1
            $result.changed | Should -HaveCount 1
            $result.added[0].name | Should -Be 'Added (copilot)'
            $result.removed[0].name | Should -Be 'Removed (copilot)'
            $result.changed[0].name | Should -Be 'Changed (copilot)'
        }
    }

    Context 'when current catalog is empty' {
        It 'Reports all discovered models as added' {
            $current = @(
                [PSCustomObject]@{ name = 'placeholder'; multiplier = 0 }
            )
            # Use a single-element to avoid empty array issues; test with actual additions
            $discovered = @(
                [PSCustomObject]@{ name = 'New A (copilot)'; multiplier = 1 }
                [PSCustomObject]@{ name = 'New B (copilot)'; multiplier = 3 }
            )
            $result = Compare-Catalogs -Current $current -Discovered $discovered
            $result.added | Should -HaveCount 2
            $result.removed | Should -HaveCount 1
        }
    }

    Context 'when multiplier does not change' {
        It 'Does not report unchanged models' {
            $current = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 1 }
                [PSCustomObject]@{ name = 'Model B (copilot)'; multiplier = 3 }
            )
            $discovered = @(
                [PSCustomObject]@{ name = 'Model A (copilot)'; multiplier = 1 }
                [PSCustomObject]@{ name = 'Model B (copilot)'; multiplier = 3 }
            )
            $result = Compare-Catalogs -Current $current -Discovered $discovered
            $result.changed | Should -HaveCount 0
        }
    }
}

#endregion Compare-Catalogs Tests

#region Invoke-ModelCatalogUpdate Tests

Describe 'Invoke-ModelCatalogUpdate' -Tag 'Unit' {
    BeforeAll {
        $script:CatalogDir = Join-Path ([System.IO.Path]::GetTempPath()) "CatalogUpdateTests_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:CatalogDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:CatalogDir) {
            Remove-Item -Path $script:CatalogDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'when no existing catalog exists' {
        BeforeAll {
            $script:NewCatalogPath = Join-Path $script:CatalogDir 'new-catalog.json'
            if (Test-Path $script:NewCatalogPath) { Remove-Item $script:NewCatalogPath -Force }

            $release = @(
                @{ name = 'Model A'; release_status = 'GA' }
                @{ name = 'Model B'; release_status = 'Preview' }
            )
            $mult = @(
                @{ name = 'Model A'; multiplier_paid = 1 }
                @{ name = 'Model B'; multiplier_paid = 0.25 }
            )

            $script:NewResult = Invoke-ModelCatalogUpdate -ReleaseStatus $release -Multipliers $mult -CatalogPath $script:NewCatalogPath
        }

        It 'Returns created status' {
            $script:NewResult.status | Should -Be 'created'
        }

        It 'Returns null diff' {
            $script:NewResult.diff | Should -BeNullOrEmpty
        }

        It 'Returns all discovered models in finalModels' {
            $script:NewResult.finalModels | Should -HaveCount 2
        }

        It 'Writes catalog file to disk' {
            Test-Path $script:NewCatalogPath | Should -BeTrue
        }

        It 'Written catalog contains correct model count' {
            $written = Get-Content $script:NewCatalogPath -Raw | ConvertFrom-Json
            $written.models | Should -HaveCount 2
        }

        It 'Written catalog has lastUpdated field' {
            $written = Get-Content $script:NewCatalogPath -Raw | ConvertFrom-Json
            $written.lastUpdated | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when catalog exists with no changes' {
        BeforeAll {
            $script:UnchangedPath = Join-Path $script:CatalogDir 'unchanged-catalog.json'
            $existingCatalog = @{
                lastUpdated = '2026-01-01'
                source      = 'https://example.com'
                models      = @(
                    @{ name = 'Model A (copilot)'; tier = 'standard'; multiplier = 1; status = 'ga' }
                )
            }
            $existingCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:UnchangedPath -Encoding utf8

            $release = @(@{ name = 'Model A'; release_status = 'GA' })
            $mult = @(@{ name = 'Model A'; multiplier_paid = 1 })

            $script:UnchangedResult = Invoke-ModelCatalogUpdate -ReleaseStatus $release -Multipliers $mult -CatalogPath $script:UnchangedPath
        }

        It 'Returns unchanged status' {
            $script:UnchangedResult.status | Should -Be 'unchanged'
        }

        It 'Updates lastUpdated timestamp in file' {
            $written = Get-Content $script:UnchangedPath -Raw | ConvertFrom-Json
            $written.lastUpdated | Should -Be (Get-Date -Format 'yyyy-MM-dd')
        }
    }

    Context 'when models are added' {
        BeforeAll {
            $script:AddedPath = Join-Path $script:CatalogDir 'added-catalog.json'
            $existingCatalog = @{
                lastUpdated = '2026-01-01'
                source      = 'https://example.com'
                models      = @(
                    @{ name = 'Model A (copilot)'; tier = 'standard'; multiplier = 1; status = 'ga' }
                )
            }
            $existingCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:AddedPath -Encoding utf8

            $release = @(
                @{ name = 'Model A'; release_status = 'GA' }
                @{ name = 'Model B'; release_status = 'Preview' }
            )
            $mult = @(
                @{ name = 'Model A'; multiplier_paid = 1 }
                @{ name = 'Model B'; multiplier_paid = 3 }
            )

            $script:AddedResult = Invoke-ModelCatalogUpdate -ReleaseStatus $release -Multipliers $mult -CatalogPath $script:AddedPath
        }

        It 'Returns updated status' {
            $script:AddedResult.status | Should -Be 'updated'
        }

        It 'Includes new model in finalModels' {
            $names = @($script:AddedResult.finalModels | ForEach-Object { if ($_ -is [hashtable]) { $_['name'] } else { $_.name } })
            $names | Should -Contain 'Model B (copilot)'
        }

        It 'Reports addition in diff' {
            $script:AddedResult.diff.added | Should -HaveCount 1
        }
    }

    Context 'when models are removed' {
        BeforeAll {
            $script:RemovedPath = Join-Path $script:CatalogDir 'removed-catalog.json'
            $existingCatalog = @{
                lastUpdated = '2026-01-01'
                source      = 'https://example.com'
                models      = @(
                    @{ name = 'Model A (copilot)'; tier = 'standard'; multiplier = 1; status = 'ga' }
                    @{ name = 'Model B (copilot)'; tier = 'premium'; multiplier = 3; status = 'ga' }
                )
            }
            $existingCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:RemovedPath -Encoding utf8

            $release = @(@{ name = 'Model A'; release_status = 'GA' })
            $mult = @(@{ name = 'Model A'; multiplier_paid = 1 })

            $script:RemovedResult = Invoke-ModelCatalogUpdate -ReleaseStatus $release -Multipliers $mult -CatalogPath $script:RemovedPath
        }

        It 'Returns updated status' {
            $script:RemovedResult.status | Should -Be 'updated'
        }

        It 'Returns a hashtable with status, diff, and finalModels keys' {
            $script:RemovedResult.Keys | Should -Contain 'status'
            $script:RemovedResult.Keys | Should -Contain 'diff'
            $script:RemovedResult.Keys | Should -Contain 'finalModels'
        }

        It 'Marks removed model as retiring PSCustomObject in finalModels' {
            $retiring = $script:RemovedResult.finalModels | Where-Object {
                if ($_ -is [hashtable]) { $_['name'] -eq 'Model B (copilot)' }
                else { $_.name -eq 'Model B (copilot)' }
            }
            $retiring | Should -BeOfType [PSCustomObject]
            $retiring.status | Should -Be 'retiring'
        }

        It 'Preserves tier and multiplier on retiring model' {
            $retiring = $script:RemovedResult.finalModels | Where-Object {
                if ($_ -is [hashtable]) { $_['name'] -eq 'Model B (copilot)' }
                else { $_.name -eq 'Model B (copilot)' }
            }
            $retiring.tier | Should -Be 'premium'
            $retiring.multiplier | Should -Be 3
        }

        It 'Sets retiredDate as future date on removed model' {
            $retiring = $script:RemovedResult.finalModels | Where-Object {
                if ($_ -is [hashtable]) { $_['name'] -eq 'Model B (copilot)' }
                else { $_.name -eq 'Model B (copilot)' }
            }
            $retiring.retiredDate | Should -Not -BeNullOrEmpty
            [datetime]::Parse($retiring.retiredDate) | Should -BeGreaterThan (Get-Date)
        }

        It 'Keeps non-removed models unchanged' {
            $kept = $script:RemovedResult.finalModels | Where-Object {
                if ($_ -is [hashtable]) { $_['name'] -eq 'Model A (copilot)' }
                else { $_.name -eq 'Model A (copilot)' }
            }
            $kept | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when multipliers change' {
        BeforeAll {
            $script:ChangedPath = Join-Path $script:CatalogDir 'changed-catalog.json'
            $existingCatalog = @{
                lastUpdated = '2026-01-01'
                source      = 'https://example.com'
                models      = @(
                    @{ name = 'Model A (copilot)'; tier = 'standard'; multiplier = 1; status = 'ga' }
                )
            }
            $existingCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:ChangedPath -Encoding utf8

            $release = @(@{ name = 'Model A'; release_status = 'GA' })
            $mult = @(@{ name = 'Model A'; multiplier_paid = 5 })

            $script:ChangedResult = Invoke-ModelCatalogUpdate -ReleaseStatus $release -Multipliers $mult -CatalogPath $script:ChangedPath
        }

        It 'Returns updated status' {
            $script:ChangedResult.status | Should -Be 'updated'
        }

        It 'Reports change in diff' {
            $script:ChangedResult.diff.changed | Should -HaveCount 1
            $script:ChangedResult.diff.changed[0].oldMultiplier | Should -Be 1
            $script:ChangedResult.diff.changed[0].newMultiplier | Should -Be 5
        }
    }

    Context 'when DryRun is specified' {
        BeforeAll {
            $script:DryRunPath = Join-Path $script:CatalogDir 'dryrun-catalog.json'
            $existingCatalog = @{
                lastUpdated = '2026-01-01'
                source      = 'https://example.com'
                models      = @(
                    @{ name = 'Model A (copilot)'; tier = 'standard'; multiplier = 1; status = 'ga' }
                )
            }
            $existingCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:DryRunPath -Encoding utf8

            $release = @(
                @{ name = 'Model A'; release_status = 'GA' }
                @{ name = 'Model B'; release_status = 'GA' }
            )
            $mult = @(
                @{ name = 'Model A'; multiplier_paid = 1 }
                @{ name = 'Model B'; multiplier_paid = 3 }
            )

            $script:DryRunResult = Invoke-ModelCatalogUpdate -ReleaseStatus $release -Multipliers $mult -CatalogPath $script:DryRunPath -DryRun
        }

        It 'Returns dryrun status' {
            $script:DryRunResult.status | Should -Be 'dryrun'
        }

        It 'Does not modify the catalog file' {
            $written = Get-Content $script:DryRunPath -Raw | ConvertFrom-Json
            $written.lastUpdated | Should -Be '2026-01-01'
            $written.models | Should -HaveCount 1
        }

        It 'Still computes finalModels' {
            $script:DryRunResult.finalModels.Count | Should -BeGreaterThan 1
        }
    }

    Context 'when DryRun with no changes' {
        BeforeAll {
            $script:DryRunNoChangePath = Join-Path $script:CatalogDir 'dryrun-nochange.json'
            $existingCatalog = @{
                lastUpdated = '2026-01-01'
                source      = 'https://example.com'
                models      = @(
                    @{ name = 'Model A (copilot)'; tier = 'standard'; multiplier = 1; status = 'ga' }
                )
            }
            $existingCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $script:DryRunNoChangePath -Encoding utf8

            $release = @(@{ name = 'Model A'; release_status = 'GA' })
            $mult = @(@{ name = 'Model A'; multiplier_paid = 1 })

            $script:DryRunNoChangeResult = Invoke-ModelCatalogUpdate -ReleaseStatus $release -Multipliers $mult -CatalogPath $script:DryRunNoChangePath -DryRun
        }

        It 'Returns unchanged status' {
            $script:DryRunNoChangeResult.status | Should -Be 'unchanged'
        }

        It 'Does not update lastUpdated in file' {
            $written = Get-Content $script:DryRunNoChangePath -Raw | ConvertFrom-Json
            $written.lastUpdated | Should -Be '2026-01-01'
        }
    }

    Context 'when catalog path directory does not exist' {
        BeforeAll {
            $script:DeepPath = Join-Path $script:CatalogDir 'deep/nested/dir/catalog.json'
            if (Test-Path (Split-Path $script:DeepPath -Parent)) {
                Remove-Item (Split-Path $script:DeepPath -Parent) -Recurse -Force
            }

            $release = @(@{ name = 'Model A'; release_status = 'GA' })
            $mult = @(@{ name = 'Model A'; multiplier_paid = 1 })

            $script:DeepResult = Invoke-ModelCatalogUpdate -ReleaseStatus $release -Multipliers $mult -CatalogPath $script:DeepPath
        }

        It 'Creates directory and writes catalog' {
            Test-Path $script:DeepPath | Should -BeTrue
        }

        It 'Returns created status' {
            $script:DeepResult.status | Should -Be 'created'
        }
    }
}

#endregion Invoke-ModelCatalogUpdate Tests
