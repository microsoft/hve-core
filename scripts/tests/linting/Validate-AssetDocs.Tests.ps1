#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    # Dot-source the generator first so its -Force module re-imports (DocsHelpers
    # -> -> CIHelpers) settle before the validator runs its own
    # imports. The validator's explicit imports then land last, keeping every
    # command it uses (including Write-CIAnnotation) in this script's scope. The
    # generator also provides Invoke-AssetDocsGeneration for scaffolding fixtures.
    . (Join-Path $PSScriptRoot '../../docs/Generate-AssetDocs.ps1')
    $script:ValidatorPath = (Resolve-Path (Join-Path $PSScriptRoot '../../linting/Validate-AssetDocs.ps1')).Path
    . $script:ValidatorPath
    $script:TemplatePath = (Resolve-Path (Join-Path $PSScriptRoot '../../docs/templates/asset-doc.template.md')).Path

    $script:validatorFixtureCounter = 0
    function script:New-ValidatorFixture {
        param([switch]$IncludeSkill, [switch]$IncludePrompt)

        $script:validatorFixtureCounter++
        $repo = Join-Path $TestDrive "validator-fixture-$($script:validatorFixtureCounter)"
        $gh = Join-Path $repo '.github'

        $fixtures = @{
            'agents/hve-core/demo-agent.agent.md'      = @('---', 'name: Demo Agent', 'description: A demo agent.', '---', '', '# Body')
            'instructions/shared/demo.instructions.md' = @('---', 'description: Demo instructions.', 'applyTo: "**/*.ps1"', '---', '', '# Body')
        }
        if ($IncludeSkill) {
            $fixtures['skills/hve-core/demo/SKILL.md'] = @('---', 'name: demo', 'description: A demo skill.', 'user-invocable: true', '---', '', '# Body')
            $fixtures['skills/hve-core/demo/references/usage.md'] = @('# Usage', '', 'Fixture supporting content.')
        }
        if ($IncludePrompt) {
            $fixtures['prompts/hve-core/demo.prompt.md'] = @('---', 'description: A demo prompt.', '---', '', '# Body')
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

    # Rewrites the value cell of a named field in a generated metadata table
    # without depending on the column padding Format-MarkdownTable emits, so sync
    # tamper tests never silently no-op if the table formatting changes. Throws
    # when the field row is not found (tamper had no effect), surfacing a format
    # drift as an explicit failure instead of a false pass.
    function script:Set-TamperedMetadataCell {
        param([string]$Content, [string]$Field, [string]$NewValue)
        $pattern = '(?m)^(\|[ \t]*' + [regex]::Escape($Field) + '[ \t]*\|[ \t]*)[^|\r\n]*?([ \t]*\|)'
        $tampered = [regex]::Replace($Content, $pattern, { param($m) $m.Groups[1].Value + $NewValue + $m.Groups[2].Value })
        if ($tampered -eq $Content) {
            throw "Set-TamperedMetadataCell found no '$Field' metadata row to tamper; the generated table format may have changed."
        }
        return $tampered
    }
}

AfterAll {
    Remove-Module DocsHelpers, CIHelpers -Force -ErrorAction SilentlyContinue
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

    It 'Does not accept a miscased page as satisfying coverage' {
        # On case-insensitive filesystems a miscased page (docs/reference/Agents/...)
        # would satisfy Test-Path; coverage must compare case-sensitively so the
        # correctly-cased page is still reported missing. Simulate by giving the
        # model an uppercased DocRel while the real page stays lowercase.
        $miscased = $script:models | ForEach-Object {
            if ($_.Kind -eq 'agent') {
                $clone = $_.PSObject.Copy()
                $clone.DocRel = $_.DocRel -replace '^docs/reference/agents/', 'docs/reference/Agents/'
                $clone
            }
            else {
                $_
            }
        }
        $findings = @(Test-AssetDocCoverage -Models $miscased -RepoRoot $script:repo)
        $findings.Count | Should -Be 1
        $findings[0].Category | Should -Be 'Coverage'
        $findings[0].Path | Should -Be 'docs/reference/Agents/hve-core/demo-agent.md'
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

    It 'Flags a page whose path case differs from the expected model path' {
        # A miscased page (docs/reference/Agents/...) must still be treated as an
        # orphan on case-sensitive filesystems. Simulate the case difference by
        # giving the model an uppercased DocRel while the real page stays
        # lowercase, so the comparison is exercised regardless of the host
        # filesystem's own case sensitivity.
        $miscased = $script:models | ForEach-Object {
            if ($_.Kind -eq 'agent') {
                $clone = $_.PSObject.Copy()
                $clone.DocRel = $_.DocRel -replace '^docs/reference/agents/', 'docs/reference/Agents/'
                $clone
            }
            else {
                $_
            }
        }
        $findings = @(Test-AssetDocOrphan -Models $miscased -RepoRoot $script:repo)
        $findings.Count | Should -Be 1
        $findings[0].Category | Should -Be 'Orphan'
        $findings[0].Path | Should -Be 'docs/reference/agents/hve-core/demo-agent.md'
    }

    It 'Reports an error for a page with no matching asset' {
        $ghost = Join-Path $script:repo 'docs/reference/agents/hve-core/ghost.md'
        Set-Content -LiteralPath $ghost -Value (@('---', 'title: Ghost', 'description: x', '---', '') -join "`n") -Encoding utf8NoBOM
        $findings = @(Test-AssetDocOrphan -Models $script:models -RepoRoot $script:repo)
        $findings.Count | Should -Be 1
        $findings[0].Level | Should -Be 'Error'
        $findings[0].Category | Should -Be 'Orphan'
    }

    It 'Ignores an unrelated orphan in changed-file scope' {
        $ghost = Join-Path $script:repo 'docs/reference/agents/hve-core/ghost.md'
        Set-Content -LiteralPath $ghost -Value (@('---', 'title: Ghost', 'description: x', '---', '') -join "`n") -Encoding utf8NoBOM

        Test-AssetDocOrphan -Models $script:models -RepoRoot $script:repo -ChangedFiles @('README.md') |
            Should -BeNullOrEmpty
    }

    It 'Reports an orphan page when the page changed' {
        $ghostRel = 'docs/reference/agents/hve-core/ghost.md'
        Set-Content -LiteralPath (Join-Path $script:repo $ghostRel) -Value (@('---', 'title: Ghost', 'description: x', '---', '') -join "`n") -Encoding utf8NoBOM

        $findings = @(Test-AssetDocOrphan -Models $script:models -RepoRoot $script:repo -ChangedFiles @($ghostRel))

        $findings | Should -HaveCount 1
        $findings[0].Path | Should -BeExactly $ghostRel
    }

    It 'Reports an orphan page when its would-be source changed' {
        $ghostRel = 'docs/reference/agents/hve-core/ghost.md'
        Set-Content -LiteralPath (Join-Path $script:repo $ghostRel) -Value (@('---', 'title: Ghost', 'description: x', '---', '') -join "`n") -Encoding utf8NoBOM

        $findings = @(Test-AssetDocOrphan -Models $script:models -RepoRoot $script:repo -ChangedFiles @('.github/agents/hve-core/ghost.agent.md'))

        $findings | Should -HaveCount 1
        $findings[0].Path | Should -BeExactly $ghostRel
    }
}

Describe 'Changed asset-doc path mapping' -Tag 'Unit' {
    It 'Maps page paths to would-be source assets' -ForEach @(
        @{ Doc = 'docs/reference/agents/hve-core/demo.md'; Source = '.github/agents/hve-core/demo.agent.md' }
        @{ Doc = 'docs/reference/prompts/hve-core/demo.md'; Source = '.github/prompts/hve-core/demo.prompt.md' }
        @{ Doc = 'docs/reference/instructions/shared/demo.md'; Source = '.github/instructions/shared/demo.instructions.md' }
        @{ Doc = 'docs/reference/skills/hve-core/demo.md'; Source = '.github/skills/hve-core/demo' }
    ) {
        Get-AssetDocSourcePath -DocPath $Doc | Should -BeExactly $Source
    }

    It 'Selects a model when its source page or nested skill content changed' {
        $repo = New-ValidatorFixture
        $agent = Get-FixtureModel -Repo $repo -Kind 'agent'

        Test-AssetDocModelChanged -Model $agent -ChangedFiles @($agent.SourceRel) | Should -BeTrue
        Test-AssetDocModelChanged -Model $agent -ChangedFiles @($agent.DocRel) | Should -BeTrue
        Test-AssetDocModelChanged -Model $agent -ChangedFiles @('README.md') | Should -BeFalse
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

    It 'Accepts an instruction page without the optional Example usage section' {
        $script:instrContent | Should -Match '(?m)^## Example usage$'
        $withoutExample = $script:instrContent -replace '## Example usage', '## Renamed'

        Test-AssetDocStructure -Model $script:instrModel -Content $withoutExample | Should -BeNullOrEmpty
    }

    It 'Flags applicable sections that appear out of canonical contract order' {
        # Swap two heading names so every required heading is still present and
        # only the sequence drifts from the shared contract.
        $reordered = $script:agentContent -replace '## When to use it', '## __swap__' -replace '## Example usage', '## When to use it' -replace '## __swap__', '## Example usage'
        $findings = @(Test-AssetDocStructure -Model $script:agentModel -Content $reordered)

        ($findings | Where-Object { $_.Message -match 'Missing required section' }) | Should -BeNullOrEmpty
        ($findings | Where-Object { $_.Category -eq 'Structure' -and $_.Message -match 'canonical contract order' }) | Should -Not -BeNullOrEmpty
    }

    It 'Rejects a stubbed duplicate after an authored contract section' {
        $content = $script:instrContent
        foreach ($heading in @('## When to use it', '## Example usage')) {
            $body = Get-AssetDocSectionBody -Content $content -Heading $heading
            $content = $content.Replace($body, "Authored guidance for $heading.")
        }
        $content += "`n`n## When to use it`n`n<!-- asset-docs:stub -->`nDuplicate placeholder.`n"

        Test-AssetDocAuthored -Model $script:instrModel -Content $content -RequireAuthoredContent instruction |
            Should -BeNullOrEmpty

        $findings = @(Test-AssetDocStructure -Model $script:instrModel -Content $content)
        $duplicates = @($findings | Where-Object { $_.Category -eq 'Structure' -and $_.Message -match 'Duplicate section' })

        $duplicates | Should -HaveCount 1
        $duplicates[0].Level | Should -Be 'Error'
        $duplicates[0].Message | Should -Match ([regex]::Escape('## When to use it'))
    }

    It 'Order-checks an optional section the page includes' {
        $reordered = $script:instrContent -replace '## When to use it', '## __swap__' -replace '## Example usage', '## When to use it' -replace '## __swap__', '## Example usage'
        $findings = @(Test-AssetDocStructure -Model $script:instrModel -Content $reordered)

        ($findings | Where-Object { $_.Category -eq 'Structure' -and $_.Message -match 'canonical contract order' }) | Should -Not -BeNullOrEmpty
    }

    It 'Derives every required heading from the shared contract' {
        $requiredSections = @(Get-AssetDocSectionContract | Where-Object {
                (Resolve-AssetDocSectionStatus -Section $_ -Kind $script:instrModel.Kind -Interactive $script:instrModel.Interactive) -eq 'Required'
            })

        foreach ($section in $requiredSections) {
            $broken = $script:instrContent -replace [regex]::Escape($section.Heading), '## Renamed'
            $findings = @(Test-AssetDocStructure -Model $script:instrModel -Content $broken)

            ($findings | Where-Object { $_.Message -match [regex]::Escape($section.Heading) }) |
                Should -Not -BeNullOrEmpty
        }
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

    It 'Reports no drift when the page uses CRLF line endings' {
        $crlfContent = ($script:agentContent -replace '\r\n', "`n") -replace '\r', "`n" -replace '\n', "`r`n"
        Test-AssetDocRegionSync -Model $script:agentModel -Content $crlfContent | Should -BeNullOrEmpty
    }

    It 'Reports no drift when the page uses lone CR line endings' {
        $crContent = ($script:agentContent -replace '\r\n', "`n") -replace '\r', "`n" -replace '\n', "`r"
        Test-AssetDocRegionSync -Model $script:agentModel -Content $crContent | Should -BeNullOrEmpty
    }

    It 'Detects a tampered metadata region' {
        $tampered = Set-TamperedMetadataCell -Content $script:agentContent -Field 'Kind' -NewValue 'TAMPERED'
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
        $script:instrModel = Get-FixtureModel -Repo $script:repo -Kind 'instruction'
        $script:agentContent = Get-Content -LiteralPath (Join-Path $script:repo $script:agentModel.DocRel) -Raw
        $script:instrContent = Get-Content -LiteralPath (Join-Path $script:repo $script:instrModel.DocRel) -Raw
    }

    It 'Warns when stub placeholders remain by default' {
        $findings = @(Test-AssetDocAuthored -Model $script:agentModel -Content $script:agentContent)
        $findings.Count | Should -Be 1
        $findings[0].Level | Should -Be 'Warning'
        $findings[0].Category | Should -Be 'Authored'
    }

    It 'Errors on Required stubs when the model kind is selected' {
        $findings = @(Test-AssetDocAuthored -Model $script:agentModel -Content $script:agentContent -RequireAuthoredContent agent)
        $findings[0].Level | Should -Be 'Error'
    }

    It 'Leaves Required stubs as warnings when the model kind is not selected' {
        $findings = @(Test-AssetDocAuthored -Model $script:agentModel -Content $script:agentContent -RequireAuthoredContent instruction)
        $findings | Should -HaveCount 1
        $findings[0].Level | Should -Be 'Warning'
    }

    It 'Treats an Optional-only instruction stub as a warning under strict instruction validation' {
        $content = "## When to use it`n`nUse these instructions for the fixture.`n`n## Example usage`n`n<!-- asset-docs:stub -->`nExample placeholder.`n"
        $findings = @(Test-AssetDocAuthored -Model $script:instrModel -Content $content -RequireAuthoredContent instruction)

        $findings | Should -HaveCount 1
        $findings[0].Level | Should -Be 'Warning'
        $findings[0].Message | Should -Match ([regex]::Escape('## Example usage'))
        $findings[0].Message | Should -Not -Match ([regex]::Escape('## When to use it'))
    }

    It 'Ignores a sentinel in a NotApplicable instruction section' {
        $content = "## When to use it`n`nUse these instructions for the fixture.`n`n## How to use it`n`n<!-- asset-docs:stub -->`nNot applicable.`n"

        Test-AssetDocAuthored -Model $script:instrModel -Content $content -RequireAuthoredContent instruction |
            Should -BeNullOrEmpty
    }

    It 'Reports one Error naming every stubbed Required section' {
        $findings = @(Test-AssetDocAuthored -Model $script:agentModel -Content $script:agentContent -RequireAuthoredContent agent)

        $findings | Should -HaveCount 1
        $findings[0].Level | Should -Be 'Error'
        $findings[0].Message | Should -Match ([regex]::Escape('## When to use it'))
        $findings[0].Message | Should -Match ([regex]::Escape('## How to use it'))
        $findings[0].Message | Should -Match ([regex]::Escape('## Example usage'))
    }

    It 'Applies cumulative strict kinds' {
        (Test-AssetDocAuthored -Model $script:agentModel -Content $script:agentContent -RequireAuthoredContent @('instruction', 'agent')).Level |
            Should -Be 'Error'
        (Test-AssetDocAuthored -Model $script:instrModel -Content $script:instrContent -RequireAuthoredContent @('instruction', 'agent')).Level |
            Should -Be 'Error'
    }

    It 'Reports nothing when an Optional section is omitted' {
        $content = "## When to use it`n`nUse these instructions for the fixture.`n"

        Test-AssetDocAuthored -Model $script:instrModel -Content $content -RequireAuthoredContent instruction |
            Should -BeNullOrEmpty
    }

    It 'Reports nothing when stubs are removed' {
        $authored = $script:agentContent -replace '<!-- asset-docs:stub -->', ''
        Test-AssetDocAuthored -Model $script:agentModel -Content $authored | Should -BeNullOrEmpty
    }
}

Describe 'Skill authored completeness rollout' -Tag 'Unit' {
    BeforeAll {
        $script:skillRepo = New-ValidatorFixture -IncludeSkill -IncludePrompt
        $script:skillModel = Get-FixtureModel -Repo $script:skillRepo -Kind 'skill'
        $script:skillContent = Get-Content -LiteralPath (Join-Path $script:skillRepo $script:skillModel.DocRel) -Raw
        $script:strictKinds = @('instruction', 'prompt', 'skill')
    }

    It 'Rejects <Label> required skill stubs in one finding' -ForEach @(
        @{ Label = 'When-only'; StubHeadings = @('## When to use it') }
        @{ Label = 'Example-only'; StubHeadings = @('## Example usage') }
        @{ Label = 'both'; StubHeadings = @('## When to use it', '## Example usage') }
    ) {
        $content = $script:skillContent
        foreach ($heading in @('## When to use it', '## Example usage')) {
            if ($heading -notin $StubHeadings) {
                $body = Get-AssetDocSectionBody -Content $content -Heading $heading
                $content = $content.Replace($body, "Authored guidance for $heading.")
            }
        }

        $findings = @(Test-AssetDocAuthored -Model $script:skillModel -Content $content -RequireAuthoredContent $script:strictKinds)

        $findings | Should -HaveCount 1
        $findings[0].Level | Should -Be 'Error'
        $findings[0].Category | Should -Be 'Authored'
        $findings[0].Path | Should -BeExactly $script:skillModel.DocRel
        foreach ($heading in @('## When to use it', '## Example usage')) {
            if ($heading -in $StubHeadings) {
                $findings[0].Message | Should -Match ([regex]::Escape($heading))
            }
            else {
                $findings[0].Message | Should -Not -Match ([regex]::Escape($heading))
            }
        }
        $findings[0].Message | Should -Not -Match 'How to use it'
    }

    It 'Accepts authored skill sections without a How section' {
        $content = $script:skillContent
        foreach ($heading in @('## When to use it', '## Example usage')) {
            $body = Get-AssetDocSectionBody -Content $content -Heading $heading
            $content = $content.Replace($body, "Authored guidance for $heading.")
        }

        $content | Should -Not -Match '(?m)^## How to use it'
        Test-AssetDocStructure -Model $script:skillModel -Content $content | Should -BeNullOrEmpty
        Test-AssetDocAuthored -Model $script:skillModel -Content $content -RequireAuthoredContent $script:strictKinds |
            Should -BeNullOrEmpty
    }

    It 'Preserves strict <Kind> enforcement alongside skills' -ForEach @(
        @{ Kind = 'instruction' }
        @{ Kind = 'prompt' }
    ) {
        $model = Get-FixtureModel -Repo $script:skillRepo -Kind $Kind
        $content = Get-Content -LiteralPath (Join-Path $script:skillRepo $model.DocRel) -Raw

        (Test-AssetDocAuthored -Model $model -Content $content -RequireAuthoredContent $script:strictKinds).Level |
            Should -Be 'Error'
    }

    It 'Keeps agent stubs advisory under cumulative enforcement' {
        $model = Get-FixtureModel -Repo $script:skillRepo -Kind 'agent'
        $content = Get-Content -LiteralPath (Join-Path $script:skillRepo $model.DocRel) -Raw
        $findings = @(Test-AssetDocAuthored -Model $model -Content $content -RequireAuthoredContent $script:strictKinds)

        $findings | Should -HaveCount 1
        $findings[0].Level | Should -Be 'Warning'
    }

    It 'Keeps an optional instruction example advisory under cumulative enforcement' {
        $model = Get-FixtureModel -Repo $script:skillRepo -Kind 'instruction'
        $content = Get-Content -LiteralPath (Join-Path $script:skillRepo $model.DocRel) -Raw
        $body = Get-AssetDocSectionBody -Content $content -Heading '## When to use it'
        $content = $content.Replace($body, 'Use these instructions for fixture scripts.')
        $findings = @(Test-AssetDocAuthored -Model $model -Content $content -RequireAuthoredContent $script:strictKinds)

        $findings | Should -HaveCount 1
        $findings[0].Level | Should -Be 'Warning'
        $findings[0].Message | Should -Match 'Example usage'
    }

    It 'Ignores a sentinel in the NotApplicable skill How section' {
        $content = "## When to use it`n`nUse the fixture skill.`n`n## How to use it`n`n<!-- asset-docs:stub -->`n`n## Example usage`n`nAsk for the fixture output.`n"

        Test-AssetDocAuthored -Model $script:skillModel -Content $content -RequireAuthoredContent $script:strictKinds |
            Should -BeNullOrEmpty
    }

    It 'Applies changed-file skill enforcement for <Label>' -ForEach @(
        @{ Label = 'nested support content'; ChangedPath = '.github/skills/hve-core/demo/references/usage.md'; ExitCode = 1; Selected = 1 }
        @{ Label = 'the skill page'; ChangedPath = 'docs/reference/skills/hve-core/demo.md'; ExitCode = 1; Selected = 1 }
        @{ Label = 'an unrelated path'; ChangedPath = 'README.md'; ExitCode = 0; Selected = 0 }
    ) {
        Mock Get-ChangedFilesFromGit { @($ChangedPath) }
        $output = Join-Path $TestDrive 'skill-changed-results.json'

        Invoke-AssetDocsValidation -RepoRoot $script:skillRepo -ChangedFilesOnly -FailOnMissing -CheckSync -RequireAuthoredContent $script:strictKinds -OutputPath $output |
            Should -Be $ExitCode

        $result = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
        $findings = @($result.findings | Where-Object { $_.Category -eq 'Authored' })
        $findings | Should -HaveCount $Selected
        if ($Selected) {
            $findings[0].Path | Should -BeExactly $script:skillModel.DocRel
            $findings[0].Level | Should -Be 'Error'
        }
    }

    It 'Binds all three strict kinds through the CLI with skill stub <Stub>' -ForEach @(
        @{ Stub = $true; ExitCode = 1 }
        @{ Stub = $false; ExitCode = 0 }
    ) {
        $repo = New-ValidatorFixture -IncludeSkill -IncludePrompt
        foreach ($model in (Get-FixtureModels -Repo $repo | Where-Object { $_.Kind -in $script:strictKinds })) {
            $page = Join-Path $repo $model.DocRel
            $content = Get-Content -LiteralPath $page -Raw
            foreach ($section in (Get-AssetDocSectionContract | Where-Object { $_.TemplateRegion })) {
                if ((Resolve-AssetDocSectionStatus -Section $section -Kind $model.Kind -Interactive $model.Interactive) -ne 'Required') {
                    continue
                }
                if ($Stub -and $model.Kind -eq 'skill' -and $section.Heading -eq '## Example usage') {
                    continue
                }
                $body = Get-AssetDocSectionBody -Content $content -Heading $section.Heading
                $content = $content.Replace($body, "Authored guidance for $($section.Heading).")
            }
            Set-Content -LiteralPath $page -Value $content -Encoding utf8NoBOM -NoNewline
        }
        $output = Join-Path $repo 'logs/skill-cli.json'

        & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repo -FailOnMissing -CheckSync -RequireAuthoredContent instruction,prompt,skill -OutputPath $output *> $null

        $LASTEXITCODE | Should -Be $ExitCode
        $result = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
        @($result.options.requireAuthoredContent) | Should -Be @('instruction', 'prompt', 'skill')
        $errors = @($result.findings | Where-Object { $_.Level -eq 'Error' })
        $errors | Should -HaveCount $ExitCode
        if ($Stub) {
            $errors[0].Category | Should -Be 'Authored'
            $errors[0].Path | Should -BeExactly 'docs/reference/skills/hve-core/demo.md'
            $errors[0].Message | Should -Match 'Example usage'
        }
    }

    It 'Keeps the local and reusable CI rollout selectors aligned' {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $package = Get-Content -LiteralPath (Join-Path $root 'package.json') -Raw | ConvertFrom-Json
        $local = [regex]::Match($package.scripts.'lint:asset-docs', '-RequireAuthoredContent\s+(\S+)')
        $local.Success | Should -BeTrue

        $workflow = Get-Content -LiteralPath (Join-Path $root '.github/workflows/asset-docs-validation.yml') -Raw | ConvertFrom-Yaml
        $step = @($workflow.jobs.validate.steps | Where-Object { $_.name -eq 'Run asset documentation validation' })
        $step | Should -HaveCount 1
        $ci = [regex]::Match($step[0].run, 'RequireAuthoredContent\s*=\s*@\(([^)]*)\)')
        $ci.Success | Should -BeTrue
        $ciKinds = @([regex]::Matches($ci.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })

        @($local.Groups[1].Value -split ',') | Should -Be @('instruction', 'prompt', 'skill')
        $ciKinds | Should -Be @('instruction', 'prompt', 'skill')
    }
}

Describe 'Invoke-AssetDocsValidation' -Tag 'Unit' {
    It 'Sets the terminating error policy before top-level initialization' {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ValidatorPath,
            [ref]$tokens,
            [ref]$parseErrors
        )

        $parseErrors | Should -BeNullOrEmpty
        $firstStatement = $ast.EndBlock.Statements[0]
        $firstStatement | Should -BeOfType ([System.Management.Automation.Language.AssignmentStatementAst])
        $firstStatement.Left.VariablePath.UserPath | Should -Be 'ErrorActionPreference'
        $firstStatement.Right.Expression.Value | Should -Be 'Stop'
    }

    It 'Exposes the public validation parameters' {
        $command = Get-Command $script:ValidatorPath

        $command.Parameters.Keys | Should -Contain 'ChangedFilesOnly'
        $command.Parameters.Keys | Should -Contain 'BaseBranch'
        $command.Parameters.Keys | Should -Contain 'RequireAuthoredContent'
        $command.Parameters['RequireAuthoredContent'].ParameterType | Should -Be ([string[]])
    }

    It 'Constrains orchestration to the four documentable kinds' {
        $attribute = (Get-Command Invoke-AssetDocsValidation).Parameters['RequireAuthoredContent'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }

        $attribute.ValidValues | Should -Be @('agent', 'prompt', 'instruction', 'skill')
        { Invoke-AssetDocsValidation -RepoRoot (New-ValidatorFixture) -RequireAuthoredContent unsupported } |
            Should -Throw
    }

    It 'Binds single and comma-delimited cumulative kinds through a child pwsh process' {
        $repo = New-ValidatorFixture
        $singleOutput = Join-Path $TestDrive 'single-kind.json'
        $cumulativeOutput = Join-Path $TestDrive 'cumulative-kinds.json'

        & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repo -RequireAuthoredContent instruction -OutputPath $singleOutput *> $null
        $LASTEXITCODE | Should -Be 1
        @((Get-Content -LiteralPath $singleOutput -Raw | ConvertFrom-Json).options.requireAuthoredContent) |
            Should -Be @('instruction')

        & pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repo -RequireAuthoredContent instruction,prompt -OutputPath $cumulativeOutput *> $null
        $LASTEXITCODE | Should -Be 1
        @((Get-Content -LiteralPath $cumulativeOutput -Raw | ConvertFrom-Json).options.requireAuthoredContent) |
            Should -Be @('instruction', 'prompt')
    }

    It 'Rejects an unsupported kind through a child pwsh process' {
        $repo = New-ValidatorFixture
        $output = Join-Path $TestDrive 'invalid-kind.json'

        $messages = @(& pwsh -NoProfile -File $script:ValidatorPath -RepoRoot $repo -RequireAuthoredContent unsupported -OutputPath $output 2>&1)

        $LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $output | Should -BeFalse
        $messages -join "`n" | Should -Match 'Unsupported asset kind'
    }

    It 'Exits 0 for a freshly generated tree with authored warnings only' {
        $repo = New-ValidatorFixture
        (Invoke-AssetDocsValidation -RepoRoot $repo) | Should -Be 0
    }

    It 'Writes a JSON results file' {
        $repo = New-ValidatorFixture
        Invoke-AssetDocsValidation -RepoRoot $repo | Out-Null
        $output = Join-Path $repo 'logs/asset-docs-validation-results.json'
        Test-Path -LiteralPath $output | Should -BeTrue
        @((Get-Content -LiteralPath $output -Raw | ConvertFrom-Json).options.requireAuthoredContent) |
            Should -HaveCount 0
    }

    It 'Preserves selected kind order in the JSON results' {
        $repo = New-ValidatorFixture
        $output = Join-Path $repo 'logs/selected-kinds.json'

        Invoke-AssetDocsValidation -RepoRoot $repo -RequireAuthoredContent @('skill', 'instruction') -OutputPath $output | Out-Null

        @((Get-Content -LiteralPath $output -Raw | ConvertFrom-Json).options.requireAuthoredContent) |
            Should -Be @('skill', 'instruction')
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
        $tampered = Set-TamperedMetadataCell -Content (Get-Content -LiteralPath $page -Raw) -Field 'Kind' -NewValue 'TAMPERED'
        Set-Content -LiteralPath $page -Value $tampered -Encoding utf8NoBOM -NoNewline
        (Invoke-AssetDocsValidation -RepoRoot $repo -CheckSync) | Should -Be 1
    }

    It 'Exits 0 for a freshly generated tree under strict coverage and sync checks' {
        $repo = New-ValidatorFixture
        (Invoke-AssetDocsValidation -RepoRoot $repo -FailOnMissing -CheckSync) | Should -Be 0
    }

    It 'Does not block unrelated changes on a pre-existing orphan' {
        $repo = New-ValidatorFixture
        Set-Content -LiteralPath (Join-Path $repo 'docs/reference/agents/hve-core/ghost.md') -Value (@('---', 'title: Ghost', 'description: x', '---', '') -join "`n") -Encoding utf8NoBOM
        Mock Get-ChangedFilesFromGit { @('README.md') }

        (Invoke-AssetDocsValidation -RepoRoot $repo -ChangedFilesOnly -FailOnMissing -CheckSync) | Should -Be 0
    }

    It 'Exits 1 when an orphan page changed' {
        $repo = New-ValidatorFixture
        $ghostRel = 'docs/reference/agents/hve-core/ghost.md'
        Set-Content -LiteralPath (Join-Path $repo $ghostRel) -Value (@('---', 'title: Ghost', 'description: x', '---', '') -join "`n") -Encoding utf8NoBOM
        Mock Get-ChangedFilesFromGit { @($ghostRel) }

        (Invoke-AssetDocsValidation -RepoRoot $repo -ChangedFilesOnly -FailOnMissing -CheckSync) | Should -Be 1
    }

    It 'Exits 1 when a deleted source leaves an orphan page' {
        $repo = New-ValidatorFixture
        $model = Get-FixtureModel -Repo $repo -Kind 'agent'
        Remove-Item -LiteralPath (Join-Path $repo $model.SourceRel) -Force
        Mock Get-ChangedFilesFromGit { @($model.SourceRel) }

        (Invoke-AssetDocsValidation -RepoRoot $repo -ChangedFilesOnly -FailOnMissing -CheckSync) | Should -Be 1
    }

    It 'Exits 1 when a source rename orphans the old page and misses the new page' {
        $repo = New-ValidatorFixture
        $oldModel = Get-FixtureModel -Repo $repo -Kind 'agent'
        $newSourceRel = '.github/agents/hve-core/renamed-agent.agent.md'
        $newSource = Join-Path $repo $newSourceRel
        Move-Item -LiteralPath (Join-Path $repo $oldModel.SourceRel) -Destination $newSource
        Mock Get-ChangedFilesFromGit { @($oldModel.SourceRel, $newSourceRel) }

        (Invoke-AssetDocsValidation -RepoRoot $repo -ChangedFilesOnly -FailOnMissing -CheckSync) | Should -Be 1
    }

    It 'Exits 1 when a changed documentation page was deleted' {
        $repo = New-ValidatorFixture
        $model = Get-FixtureModel -Repo $repo -Kind 'agent'
        Remove-Item -LiteralPath (Join-Path $repo $model.DocRel) -Force
        Mock Get-ChangedFilesFromGit { @($model.DocRel) }

        (Invoke-AssetDocsValidation -RepoRoot $repo -ChangedFilesOnly -FailOnMissing -CheckSync) | Should -Be 1
    }

    It 'Passes the base branch and deleted-path switch to change discovery' {
        $repo = New-ValidatorFixture
        Mock Get-ChangedFilesFromGit { @() }

        Invoke-AssetDocsValidation -RepoRoot $repo -ChangedFilesOnly -BaseBranch 'develop' | Out-Null

        Should -Invoke Get-ChangedFilesFromGit -Times 1 -Exactly -ParameterFilter {
            $BaseBranch -eq 'develop' -and $IncludeDeleted
        }
    }
}
