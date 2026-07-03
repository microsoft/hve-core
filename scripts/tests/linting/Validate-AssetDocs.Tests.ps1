#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Validate-AssetDocs.ps1')
    $script:TemplatePath = (Resolve-Path (Join-Path $PSScriptRoot '../../docs/templates/asset-doc.template.md')).Path

    $script:validatorFixtureCounter = 0
    function script:New-ValidatorFixture {
        $script:validatorFixtureCounter++
        $repo = Join-Path $TestDrive "validator-fixture-$($script:validatorFixtureCounter)"
        $gh = Join-Path $repo '.github'

        $fixtures = @{
            'agents/hve-core/demo-agent.agent.md'      = @('---', 'name: Demo Agent', 'description: A demo agent.', '---', '', '# Body')
            'instructions/shared/demo.instructions.md' = @('---', 'description: Demo instructions.', 'applyTo: "**/*.ps1"', '---', '', '# Body')
        }
        foreach ($rel in $fixtures.Keys) {
            $full = Join-Path $gh $rel
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            Set-Content -LiteralPath $full -Value ($fixtures[$rel] -join "`n") -Encoding utf8NoBOM
        }

        Invoke-AssetDocsGeneration -RepoRoot $repo -TemplatePath $script:TemplatePath | Out-Null
        return $repo
    }

    function script:Get-FixtureModels {
        param([string]$Repo)
        return @(Get-DocumentableAssets -RepoRoot $Repo | ForEach-Object { New-AssetPageModel -Asset $_ -RepoRoot $Repo })
    }

    function script:Get-FixtureModel {
        param([string]$Repo, [string]$Kind)
        return (Get-FixtureModels -Repo $Repo | Where-Object { $_.Kind -eq $Kind } | Select-Object -First 1)
    }
}

AfterAll {
    Remove-Module DocsHelpers, CollectionHelpers, CIHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Test-AssetDocCoverage' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-ValidatorFixture
        $script:models = Get-FixtureModels -Repo $script:repo
        $script:agentModel = $script:models | Where-Object { $_.Kind -eq 'agent' }
    }

    It 'Reports no findings when every page exists' {
        Test-AssetDocCoverage -Models $script:models -RepoRoot $script:repo | Should -BeNullOrEmpty
    }

    It 'Reports a warning for a missing page by default' {
        Remove-Item -LiteralPath (Join-Path $script:repo $script:agentModel.DocRel) -Force
        $findings = @(Test-AssetDocCoverage -Models $script:models -RepoRoot $script:repo)
        $findings.Count | Should -Be 1
        $findings[0].Level | Should -Be 'Warning'
        $findings[0].Category | Should -Be 'Coverage'
    }

    It 'Reports an error for a missing page under -FailOnMissing' {
        $findings = @(Test-AssetDocCoverage -Models $script:models -RepoRoot $script:repo -FailOnMissing)
        $findings[0].Level | Should -Be 'Error'
    }
}

Describe 'Test-AssetDocOrphan' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-ValidatorFixture
        $script:models = Get-FixtureModels -Repo $script:repo
    }

    It 'Reports no orphans for a freshly generated tree' {
        Test-AssetDocOrphan -Models $script:models -RepoRoot $script:repo | Should -BeNullOrEmpty
    }

    It 'Does not flag reference index README pages as orphans' {
        # README index pages exist after generation; they must be excluded.
        Test-Path -LiteralPath (Join-Path $script:repo 'docs/reference/README.md') | Should -BeTrue
        (Test-AssetDocOrphan -Models $script:models -RepoRoot $script:repo) |
            Where-Object { $_.Path -like '*README.md' } | Should -BeNullOrEmpty
    }

    It 'Reports an error for a page with no matching asset' {
        $ghost = Join-Path $script:repo 'docs/reference/agents/hve-core/ghost.md'
        Set-Content -LiteralPath $ghost -Value (@('---', 'title: Ghost', 'description: x', '---', '') -join "`n") -Encoding utf8NoBOM
        $findings = @(Test-AssetDocOrphan -Models $script:models -RepoRoot $script:repo)
        $findings.Count | Should -Be 1
        $findings[0].Level | Should -Be 'Error'
        $findings[0].Category | Should -Be 'Orphan'
    }
}

Describe 'Test-AssetDocStructure' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-ValidatorFixture
        $script:agentModel = Get-FixtureModel -Repo $script:repo -Kind 'agent'
        $script:instrModel = Get-FixtureModel -Repo $script:repo -Kind 'instruction'
        $script:agentContent = Get-Content -LiteralPath (Join-Path $script:repo $script:agentModel.DocRel) -Raw
        $script:instrContent = Get-Content -LiteralPath (Join-Path $script:repo $script:instrModel.DocRel) -Raw
    }

    It 'Passes a complete page' {
        Test-AssetDocStructure -Model $script:agentModel -Content $script:agentContent | Should -BeNullOrEmpty
    }

    It 'Flags a missing required section' {
        $broken = $script:agentContent -replace '## Example usage', '## Renamed'
        $findings = @(Test-AssetDocStructure -Model $script:agentModel -Content $broken)
        ($findings | Where-Object { $_.Category -eq 'Structure' -and $_.Message -match 'Example usage' }) | Should -Not -BeNullOrEmpty
    }

    It 'Requires the How to use section for interactive assets' {
        $script:agentModel.Interactive | Should -BeTrue
        $broken = $script:agentContent -replace '## How to use it', '## Something else'
        ($findings = @(Test-AssetDocStructure -Model $script:agentModel -Content $broken)) | Out-Null
        ($findings | Where-Object { $_.Message -match 'How to use it' }) | Should -Not -BeNullOrEmpty
    }

    It 'Does not require the How to use section for non-interactive assets' {
        $script:instrModel.Interactive | Should -BeFalse
        # Instruction pages are generated without a How to use section.
        Test-AssetDocStructure -Model $script:instrModel -Content $script:instrContent | Should -BeNullOrEmpty
    }

    It 'Flags missing generated-region markers' {
        $broken = $script:agentContent -replace '<!-- BEGIN AUTO-GENERATED: metadata -->', '' -replace '<!-- END AUTO-GENERATED: metadata -->', ''
        $findings = @(Test-AssetDocStructure -Model $script:agentModel -Content $broken)
        ($findings | Where-Object { $_.Message -match "markers for 'metadata'" }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-AssetDocRegionSync' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-ValidatorFixture
        $script:agentModel = Get-FixtureModel -Repo $script:repo -Kind 'agent'
        $script:agentContent = Get-Content -LiteralPath (Join-Path $script:repo $script:agentModel.DocRel) -Raw
    }

    It 'Reports no drift for a freshly generated page' {
        Test-AssetDocRegionSync -Model $script:agentModel -Content $script:agentContent | Should -BeNullOrEmpty
    }

    It 'Detects a tampered metadata region' {
        $tampered = $script:agentContent -replace '\| Kind \| agent \|', '| Kind | TAMPERED |'
        $findings = @(Test-AssetDocRegionSync -Model $script:agentModel -Content $tampered)
        $findings.Count | Should -Be 1
        $findings[0].Category | Should -Be 'Sync'
        $findings[0].Level | Should -Be 'Error'
    }

    It 'Detects a tampered overview region' {
        $tampered = $script:agentContent -replace 'A demo agent\.', 'A completely different summary.'
        ($findings = @(Test-AssetDocRegionSync -Model $script:agentModel -Content $tampered)) | Out-Null
        ($findings | Where-Object { $_.Message -match 'overview' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-AssetDocAuthored' -Tag 'Unit' {
    BeforeAll {
        $script:repo = New-ValidatorFixture
        $script:agentModel = Get-FixtureModel -Repo $script:repo -Kind 'agent'
        $script:agentContent = Get-Content -LiteralPath (Join-Path $script:repo $script:agentModel.DocRel) -Raw
    }

    It 'Warns when stub placeholders remain by default' {
        $findings = @(Test-AssetDocAuthored -Model $script:agentModel -Content $script:agentContent)
        $findings.Count | Should -Be 1
        $findings[0].Level | Should -Be 'Warning'
        $findings[0].Category | Should -Be 'Authored'
    }

    It 'Errors on remaining stubs under -RequireAuthoredContent' {
        $findings = @(Test-AssetDocAuthored -Model $script:agentModel -Content $script:agentContent -RequireAuthoredContent)
        $findings[0].Level | Should -Be 'Error'
    }

    It 'Reports nothing when stubs are removed' {
        $authored = $script:agentContent -replace '<!-- asset-docs:stub -->', ''
        Test-AssetDocAuthored -Model $script:agentModel -Content $authored | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-AssetDocsValidation' -Tag 'Unit' {
    It 'Exits 0 for a freshly generated tree with authored warnings only' {
        $repo = New-ValidatorFixture
        (Invoke-AssetDocsValidation -RepoRoot $repo) | Should -Be 0
    }

    It 'Writes a JSON results file' {
        $repo = New-ValidatorFixture
        Invoke-AssetDocsValidation -RepoRoot $repo | Out-Null
        Test-Path -LiteralPath (Join-Path $repo 'logs/asset-docs-validation-results.json') | Should -BeTrue
    }

    It 'Exits 1 when an orphan page is present' {
        $repo = New-ValidatorFixture
        Set-Content -LiteralPath (Join-Path $repo 'docs/reference/agents/hve-core/ghost.md') -Value (@('---', 'title: Ghost', 'description: x', '---', '') -join "`n") -Encoding utf8NoBOM
        (Invoke-AssetDocsValidation -RepoRoot $repo) | Should -Be 1
    }

    It 'Exits 1 for a missing page under -FailOnMissing' {
        $repo = New-ValidatorFixture
        $model = Get-FixtureModel -Repo $repo -Kind 'agent'
        Remove-Item -LiteralPath (Join-Path $repo $model.DocRel) -Force
        (Invoke-AssetDocsValidation -RepoRoot $repo -FailOnMissing) | Should -Be 1
    }

    It 'Exits 0 for a missing page without -FailOnMissing' {
        $repo = New-ValidatorFixture
        $model = Get-FixtureModel -Repo $repo -Kind 'agent'
        Remove-Item -LiteralPath (Join-Path $repo $model.DocRel) -Force
        (Invoke-AssetDocsValidation -RepoRoot $repo) | Should -Be 0
    }

    It 'Exits 1 for sync drift under -CheckSync' {
        $repo = New-ValidatorFixture
        $model = Get-FixtureModel -Repo $repo -Kind 'agent'
        $page = Join-Path $repo $model.DocRel
        $tampered = (Get-Content -LiteralPath $page -Raw) -replace '\| Kind \| agent \|', '| Kind | TAMPERED |'
        Set-Content -LiteralPath $page -Value $tampered -Encoding utf8NoBOM -NoNewline
        (Invoke-AssetDocsValidation -RepoRoot $repo -CheckSync) | Should -Be 1
    }
}
